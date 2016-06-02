require 'rubydora'
require 'rexml/document'
require 'rdf/ntriples'
require 'rdf/rdfxml'

def logger
  Rails.logger
end

# Harvest metrics data from Fedora Objects
class FedoraObjectHarvester
  attr_reader :repo

  def initialize
    @repo = Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
  end

  # query for objects and process one result at a time
  def harvest
    @repo.search 'pid~und:*' do |doc|
      single_item_harvest(doc)
    end
  end

  private

  # ============================================================================
  def single_item_harvest(doc)
    pid = doc.pid
    af_model = get_af_model(doc)
    fedora_object = FedoraObject.create!(
      pid: pid,
      af_model: af_model,
      resource_type: get_resource_type(doc) || af_model,
      mimetype: get_mimetype(doc),
      bytes: get_bytes(doc),
      parent_pid: (af_model == 'GenericFile' ? get_parent_pid(doc) : pid),
      obj_ingest_date: doc.profile["objCreateDate"],
      obj_modified_date: doc.profile["objLastModDate"],
      access_rights: get_access_rights(doc)
    )
    get_and_assign_aggregation_keys(doc, fedora_object)
  end

  # splits the first element in objModels to find af_model in element 2
  def get_af_model(doc)
    doc.profile['objModels'][0].split(':')[2]
  end

  # parse from triples
  # for resource_type, use = dc/terms/type...
  # <info:fedora/und:02870v8524d> <http://purl.org/dc/terms/type> "GenericFile" .
  def get_resource_type(doc)
    return nil unless doc.datastreams.key?('descMetadata')
    resource_types = parse_triples(doc.datastreams['descMetadata'].content, 'type')
    resource_types[0] # this is an array but should only have one
  end

  DEFAULT_MIMETYPE = 'application/octet-stream'.freeze
  # if content datastream exists, use mimetype of datastream, else nil
  def get_mimetype(doc)
    return '' unless doc.datastreams.key?('content')
    doc.datastreams['content'].mimeType || DEFAULT_MIMETYPE
  end

  def get_bytes(doc)
    return 0 unless doc.datastreams.key?('content')
    doc.datastreams['content'].size || 0
  end

  # parse from XML <ns2:isPartOf rdf:resource='info:fedora/und:02870v85143' />
  def get_parent_pid(doc)
    return '' unless doc.datastreams.key?('RELS-EXT')
    parse_xml_relsext(doc.datastreams['RELS-EXT'].content, 'isPartOf')
  end

  # parse from triples: creator#administrative_unit
  # <info:fedora/und:7h149p31207>
  # <http://purl.org/dc/terms/creator#administrative_unit>
  # "University of Notre Dame::College of Science::Non-Departmental" .
  def get_and_assign_aggregation_keys(doc, fedora_object)
    return unless doc.datastreams.key?('descMetadata')
    agg_key_array = parse_triples(doc.datastreams['descMetadata'].content, 'creator#administrative_unit')
    return unless agg_key_array.any?
    agg_key_array.each do |aggregation_key|
      fedora_object.fedora_object_aggregation_keys.create!(aggregation_key: aggregation_key)
    end
  end

  # values: public, public (embargo), local, local (embargo), private, private (embargo)
  def get_access_rights(doc)
    return 'error' unless doc.datastreams.key?('rightsMetadata')
    # TODO: this is an error situation we may want to report
    parse_xml_rights(doc.datastreams['rightsMetadata'].content)
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
    machine_group_rights = this_access.elements['machine'].elements['group']
    return 'private' if machine_group_rights.nil?
    case machine_group_rights.first.to_s
    when 'public'
      'public'
    when 'registered'
      'local'
    else
      'error' # TODO: this is an error situation we may want to report
    end
  end

  # <embargo><human/><machine><date>2016-06-01</date></machine></embargo>
  # concatenate (embargo) onto prior string if it exists
  def embargo_rights(this_access)
    machine_group_rights = this_access.elements['machine'].elements['date']
    return if machine_group_rights.nil?
    return ' (embargo)' unless machine_group_rights.first.nil?
  end

  ## ============================================================================
  # We want to grab the parent_pid from the following:
  # <ns2:isPartOf rdf:resource='info:fedora/und:02870v85143' />
  def parse_xml_relsext(stream, search_key)
    # RELS-EXT is RDF-XML - parse it
    xml_hash = {}
    RDF::RDFXML::Reader.new(stream).each do |thing|
      key = thing.predicate.to_s.split("#")
      next if key[1] != search_key
      value = thing.object.to_s.split("/")
      xml_hash[key[1]] = value[1]
    end
    xml_hash[search_key]
  end

  ## ============================================================================
  # Parse triples format, returning an array of all values matching the search key.
  def parse_triples(stream, search_key)
    data_array = []
    parse_uri = 'http://purl.org/dc/terms/'
    begin
      RDF::Reader.for(:ntriples).new(stream) do |reader|
        reader.each_statement do |statement|
          key = statement.predicate.to_s
          normalized_key = key.sub(parse_uri, '')
          next if normalized_key != search_key
          data_array << statement.object
        end
      end
    rescue RDF::ReaderError => e
      logger.error(e)
      # in case of read error so it doesn't crash
    end
    data_array
  end
end
