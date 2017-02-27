# Responsible for updating parent type for all fedora object
#
# This script should be run within the context of the Rails environment via the
# `rails runner` command.
#
# ```console
# $ cd <CURRENT_WORKING_DIRECTORY>
# $ bundle exec rails runner -e <RAILS_ENV> <__FILE__>
# ```
module UpdateParentType
  module_function

  def update_parent_type
    @exceptions = []
    @repo = Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
    FedoraObject.find_each do |obj|
      begin
        if obj.af_model == 'GenericFile'
          parent_object = FedoraObject.find_by(pid: obj.parent_pid)
          if parent_object.present?
            logger.info "Get Parent Type from database for #{obj.pid}"
            obj.parent_type = parent_object.af_model
          else
            logger.info "########### Get Parent Type from Fedora for #{obj.pid} ###############"
            doc = @repo.find "und:#{obj.pid}"
            obj.parent_type = 'Unknown' unless doc.datastreams.key?('RELS-EXT')
            parent_pid = parse_xml_relsext(doc.datastreams['RELS-EXT'].content, 'isPartOf')
            parent_object = @repo.find parent_pid.to_s
            model = parent_object.profile['objModels'].select { |v| v.include?('afmodel') }
            logger.info "Pid #{doc.pid}, parent_id:#{parent_pid}, type:#{model.inspect}"
            obj.parent_type =  model.empty? ? 'Unknown' :  model.first.split(':')[2]
          end
        else
          obj.parent_type = obj.af_model
        end
        obj.save!
      rescue Exception => e
        logger.error "Error: error getting parent type for #{obj.pid}.  Error was #{e}"
        @exceptions <<  "Error: error getting parent type for #{obj.pid}.  Error: #{e}"
      end
    end
    unless @exceptions.empty?
      logger.error(@exceptions.join("\n"))
      $stderr.puts(@exceptions.join("\n"))
    end
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
end

def logger
  Rails.logger
end

UpdateParentType.update_parent_type
