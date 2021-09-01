require 'rubydora'
require 'rexml/document'
require 'rdf/ntriples'
require 'rdf/rdfxml'

def logger
  Rails.logger
end

# A custom exception class to include PID
class FedoraObjectHarvesterError < RuntimeError
  attr_reader :pid, :exception

  def initialize(pid, exception)
    @pid = pid
    @exception = exception
    super(message)
  end

  delegate :backtrace, to: :exception

  def message
    "PID: #{pid} -- #{exception.inspect}"
  end
end

# Harvest metrics data from Fedora Objects
class FedoraObjectHarvester
  attr_reader :repo, :exceptions

  def initialize(repo = default_repository)
    @repo = repo
    @exceptions = []
  end

  # query for objects and process one result at a time
  def harvest(query = 'pid~und:*')
    @repo.search(query) do |doc|
      single_item_harvest(doc)
    rescue StandardError => e
      @exceptions << FedoraObjectHarvesterError.new(doc.pid, e)
    end
    report_any_exceptions
  end

  private

  def default_repository
    Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
  end

  def report_any_exceptions
    return unless @exceptions.any?

    @exceptions.each do |exception|
      Raven.capture_exception(exception)
    end
  end

  # ============================================================================
  def single_item_harvest(doc)
    SingleItem.new(doc, self, @repo).harvest_item
  end

  # Harvest metrics data for one fedora document
  class SingleItem
    attr_reader :pid, :doc, :doc_last_modified, :harvester, :predicate_names

    def initialize(doc, harvester, repo = default_repository)
      @pid = strip_pid(doc.pid)
      @doc = doc
      @harvester = harvester
      @doc_last_modified = doc.profile['objLastModDate']
      @repo = repo
      @predicate_names = ['creator#administrative_unit', 'creator#affiliation']
    end

    # add new, update changed, or omit unchanged document
    def harvest_item
      fedora_object = FedoraObject.find_or_initialize_by(pid: pid)
      fedora_update(fedora_object) if fedora_object.new_record? || fedora_changed?(fedora_object)
    end

    def default_repository
      Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
    end

    def strip_pid(work_pid)
      work_pid.sub('und:', '')
    end

    def fedora_changed?(fedora_object)
      return true if fedora_object.updated_at.present? && fedora_object.updated_at < doc_last_modified
      return true if !fedora_object.new_record? && fedora_object.access_rights.include?('embargo')

      false
    end

    # truncate title to first 255 char (https://github.com/ndlib/hesburgh_metrics/issues/53)
    def fedora_update(fedora_object)
      fedora_object.update!(
        af_model: af_model,
        resource_type: resource_type,
        mimetype: mimetype,
        bytes: bytes,
        parent_pid: parent_pid,
        parent_type: parent_type,
        obj_ingest_date: doc.profile['objCreateDate'],
        obj_modified_date: doc_last_modified,
        access_rights: access_rights,
        title: title.slice(0, 254)
      )
      predicate_names.each do |predicate_name|
        get_and_add_or_delete_aggregation_keys(fedora_object, predicate_name)
      end
      get_and_add_or_delete_edit_groups(fedora_object)
    end

    # parse from triples: creator#administrative_unit
    # <info:fedora/und:7h149p31207>
    # <http://purl.org/dc/terms/creator#administrative_unit>
    # "University of Notre Dame::College of Science::Non-Departmental" .
    def get_and_add_or_delete_aggregation_keys(fedora_object, predicate_name)
      agg_key_array = []
      if doc.datastreams.key?('descMetadata')
        # load new aggregation_key agg_key_array
        agg_key_array = parse_triples(doc.datastreams['descMetadata'].content, predicate_name)
      end
      # if there are any aggregation keys now, add or update what is currently stored
      if agg_key_array.any?
        # add any new aggregation keys which don't already exist
        agg_key_array.each do |key|
          # add any new aggregation keys which don't already exist
          FedoraObjectAggregationKey.where(
            fedora_object: fedora_object, 
            predicate_name: predicate_name,
            aggregation_key: key
          ).first_or_initialize(&:save)
        end
      end
      # destroy any prior aggregation keys which no longer exist
      fedora_object.fedora_object_aggregation_keys.where(predicate_name: predicate_name).each do |fedora_object_aggregation_key|
        unless agg_key_array.include? fedora_object_aggregation_key.aggregation_key
          fedora_object_aggregation_key.destroy
        end
      end
    end

    # parse edit_groups from rightsMetadata, and find group name for each edit_group
    def get_and_add_or_delete_edit_groups(fedora_object)
      # find each of the edit_groups
      edit_groups_array = []
      if doc.datastreams.key?('rightsMetadata')
        edit_groups_array = parse_edit_groups(doc.datastreams['rightsMetadata'].content)
      end
      # load group name for each edit_group
      edit_groups_list = load_group_names_for(edit_groups_array)
      # add any new edit_groups which don't already exist
      if edit_groups_list.any?
        edit_groups_list.each do |edit_group|
          group_pid = strip_pid(edit_group[:group_pid])
          group_name = edit_group[:group_name]
          FedoraObjectEditGroup.where(
            fedora_object: fedora_object, 
            edit_group_pid: group_pid,
            edit_group_name: group_name
          ).first_or_initialize(&:save)
        end
      end
      # destroy any prior edit_groups which no longer exist
      fedora_object.fedora_object_edit_groups.any? do
        group_pid_array = []
        edit_groups_array.each do |pid|
          group_pid_array.push strip_pid(pid.to_s)
        end
        fedora_object.fedora_object_edit_groups.each do |edit_group|
          edit_group.destroy unless group_pid_array.include? edit_group.edit_group_pid
        end
      end
    end

    def af_model
      @af_model ||= parse_af_model
    end

    # splits objModels to find af_model in element 2
    def parse_af_model
      doc.profile['objModels'].each do |model|
        next unless model.include?('afmodel')

        return model.split(':')[2]
      end
    end

    # parse from triples
    # for resource_type, use = dc/terms/type...
    # <info:fedora/und:02870v8524d> <http://purl.org/dc/terms/type> "GenericFile" .
    def resource_type
      return af_model unless doc.datastreams.key?('descMetadata')

      resource_types = parse_triples(doc.datastreams['descMetadata'].content, 'type')
      return af_model unless resource_types[0].present?

      resource_types[0] # this is an array but should only have one
    end

    DEFAULT_MIMETYPE = 'application/octet-stream'.freeze
    # if content datastream exists, use mimetype of datastream, else nil
    def mimetype
      return '' unless doc.datastreams.key?('content')

      doc.datastreams['content'].mimeType || DEFAULT_MIMETYPE
    end

    def bytes
      return 0 unless doc.datastreams.key?('content')

      doc.datastreams['content'].size || 0
    end

    # parse from XML <ns2:isPartOf rdf:resource='info:fedora/und:02870v85143' />
    def parent_pid
      if af_model == 'GenericFile'
        return pid unless doc.datastreams.key?('RELS-EXT')

        parent = extract_parent_pid_from_doc
        return pid if parent.blank? # treat orphaned files as their own parent

        strip_pid(parent)
      else
        pid
      end
    end

    def parent_type
      if af_model == 'GenericFile'
        parent_object = FedoraObject.find_by(pid: parent_pid)
        if parent_object.present?
          parent_object.af_model
        else
          return 'Unknown' unless doc.datastreams.key?('RELS-EXT')

          parent_object = @repo.find extract_parent_pid_from_doc.to_s
          model = parent_object.profile['objModels'].select { |v| v.include?('afmodel') }
          return 'Unknown' if model.empty?

          model.first.split(':')[2]
        end
      else
        af_model
      end
    end

    # parse title from content datastream
    def title
      if af_model == 'GenericFile'
        return '' unless doc.datastreams.key?('content')

        doc.datastreams['content'].label
      else
        return '' unless doc.datastreams.key?('descMetadata')

        stream = doc.datastreams['descMetadata'].content
        parse_triples(stream, 'title').first || ''
      end
    end

    # values: public, public (embargo), local, local (embargo), private, private (embargo)
    def access_rights
      return 'private' unless doc.datastreams.key?('rightsMetadata')

      parse_xml_rights(doc.datastreams['rightsMetadata'].content)
    end

    def extract_parent_pid_from_doc
      parse_xml_relsext(doc.datastreams['RELS-EXT'].content, 'isPartOf')
    end

    # @param pid_array [Array] an array of group_pid strings
    # @return [Array] an array of hashes: {group_pid:, group_name:}
    def load_group_names_for(pid_array)
      group_elements = []
      pid_array.each do |pid|
        group_pid = pid.to_s
        group_elements.push group_pid: group_pid, group_name: get_group_name_for_pid(group_pid)
      end
      group_elements
    end

    def get_group_name_for_pid(group_pid)
      # get Fedora record for group
      group_object = @repo.find(group_pid)
      # parse descMetadata for group's name
      return '' unless doc.datastreams.key?('descMetadata')

      stream = group_object.datastreams['descMetadata'].content
      parse_triples(stream, 'title').first || 'Group name not found'
    end

    ## ============================================================================
    # create an array of edit grou pids from parsed xml doc
    def parse_edit_groups(stream)
      xml_doc = REXML::Document.new(stream)
      root = xml_doc.root
      edit_rights(root.elements["//access[@type='edit']"])
    end

    # <access type="edit"><human/><machine><person>abc</person><group>und:xxxxxx</group><group>und:xxxxxx</group></machine></access>
    def edit_rights(this_access)
      rights_array = []
      this_access.elements['machine'].get_elements('group').each do |value|
        rights_array.push value.text
      end
      rights_array
    end

    ## ============================================================================
    # create the access rights string from parsed xml doc
    def parse_xml_rights(stream)
      xml_doc = REXML::Document.new(stream)
      root = xml_doc.root
      read_rights(root.elements["//access[@type='read']"]) + embargo_rights(root.elements['//embargo']).to_s
    end

    # <access type="read"><human/><machine><group>public</group></machine></access>
    def read_rights(this_access)
      rights_array = []

      machine_group_rights = this_access.elements['machine'].get_elements('group')
      machine_group_rights.each do |value|
        rights_array.push value.text
      end

      machine_person_rights = this_access.elements['machine'].get_elements('person')
      machine_person_rights.each do |value|
        rights_array.push value.text
      end

      if rights_array.include? 'public'
        'public'
      elsif rights_array.include? 'registered'
        'local'
      elsif rights_array.include? 'private'
        'private'
      else
        'private'
      end
    end

    # <embargo><human/><machine><date>2016-06-01</date></machine></embargo>
    # concatenate (embargo) onto prior string if it exists
    def embargo_rights(this_access)
      machine_date_rights = this_access.elements['machine'].elements['date']
      return if machine_date_rights.nil? || machine_date_rights.first.blank?

      embargo_date = Date.parse(machine_date_rights.to_s)
      today = Time.zone.today
      return ' (embargo)' if embargo_date > today
    end

    ## ============================================================================
    # We want to grab the parent_pid from the following:
    # <ns2:isPartOf rdf:resource='info:fedora/und:02870v85143' />
    def parse_xml_relsext(stream, search_key)
      # RELS-EXT is RDF-XML - parse it
      xml_hash = {}
      RDF::RDFXML::Reader.new(stream).each do |thing|
        key = thing.predicate.to_s.split('#')
        next if key[1] != search_key

        value = thing.object.to_s.split('/')
        xml_hash[key[1]] = value[1]
      end
      xml_hash[search_key]
    end

    ## ============================================================================
    # Parse triples format, returning an array of all values matching the search key.
    def parse_triples(stream, search_key)
      data_array = []
      parse_uri = 'http://purl.org/dc/terms/'
      full_uri = parse_uri + search_key
      return data_array unless stream.include? full_uri

      RDF::NTriples::Reader.new(stream) do |reader|
        reader.each_statement do |statement|
          next unless statement.predicate.to_s == full_uri

          data_array << statement.object.to_s
        end
      rescue RDF::ReaderError => e
        harvester.exceptions << FedoraObjectHarvesterError.new(pid, e)
      end
      data_array.reject(&:empty?)
    end
  end
end
