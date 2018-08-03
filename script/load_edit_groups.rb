require 'rubydora'
require 'rexml/document'
require 'rdf/ntriples'
require 'rdf/rdfxml'
# Responsible for loading all FedoraObjectEditGroups based on FedoraObject
#
# This script should be run within the context of the Rails environment via the
# `rails runner` command.
#
# ```console
# $ cd <CURRENT_WORKING_DIRECTORY>
# $ bundle exec rails runner -e <RAILS_ENV> <__FILE__>
# ```
module LoadEditGroups
  module_function

  def write_edit_groups_for_fedora_object
    @exceptions = []
      @repo = Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
      FedoraObject.find_each do |fedora_object|
      begin
        pid = "und:#{fedora_object.pid}"
        logger.info "########### Get edit groups from Fedora for #{pid} ###############"
        @doc = @repo.find pid
        edit_groups_list = []
        if @doc.datastreams.key?('rightsMetadata')
          # find each of the edit_groups
          edit_groups_array = parse_edit_groups(@doc.datastreams['rightsMetadata'].content)
          # load group name for each edit_group
          edit_groups_list = load_group_names_for(edit_groups_array)
        end
          # add any new edit_groups
        if edit_groups_list.any?
          edit_groups_list.each do |edit_group|
            group_pid = strip_pid(edit_group[:group_pid])
            group_name = edit_group[:group_name]
            FedoraObjectEditGroup.where(fedora_object: fedora_object, edit_group_pid: group_pid, edit_group_name: group_name).first_or_initialize(&:save)
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
      rescue Exception => e
        logger.error "Error: error adding edit_groups for #{fedora_object.pid}.  Error was #{e}"
        @exceptions << "Error: error loading edit groups for #{fedora_object.pid}.  Error: #{e}"
      end
    end
    unless @exceptions.empty?
      logger.error @exceptions.join(" ")
    end
  end
## ============================================================================
  def strip_pid(work_pid)
    work_pid.sub('und:', '')
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
    begin
      group_object = @repo.find(group_pid)
      # parse descMetadata for group's name
      return '' unless @doc.datastreams.key?('descMetadata')
      stream = group_object.datastreams['descMetadata'].content
      parse_triples(stream, 'title').first || ''
    rescue Exception => e
      logger.error "Error: Error finding group object #{group_pid}. Error was #{e}"
      return "Group does not exist"
    end
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
  # Parse triples format, returning an array of all values matching the search key.
  def parse_triples(stream, search_key)
    data_array = []
    parse_uri = 'http://purl.org/dc/terms/'
    full_uri = parse_uri + search_key
    return data_array unless stream.include? full_uri
    RDF::NTriples::Reader.new(stream) do |reader|
      begin
        reader.each_statement do |statement|
          next unless statement.predicate.to_s == full_uri
          data_array << statement.object.to_s
        end
      rescue RDF::ReaderError => e
        logger.error "Error: error parsing for group name for #{@doc.pid}. Error was #{e}"
      end
    end
    data_array.reject(&:empty?)
  end
end

def logger
  Rails.logger
end

LoadEditGroups.write_edit_groups_for_fedora_object
