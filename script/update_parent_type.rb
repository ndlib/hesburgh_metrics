module UpdateParentType
  module_function

  def update_parent_type
    @exceptions = []
    @repo = Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
    FedoraObject.find_each do ||
      begin
        if obj.af_model == 'GenericFile'
          parent_object = FedoraObject.find_by(pid: obj.parent_pid)
          if parent_object.present?
            puts 'Get Parent Type from database'
            obj.parent_type = parent_object.af_model
          else
            doc = @repo.find "und:#{obj.pid}"
            return 'Unknown' unless doc.datastreams.key?('RELS-EXT')
            parent_pid = parse_xml_relsext(doc.datastreams['RELS-EXT'].content, 'isPartOf')
            parent_object = @repo.find parent_pid.to_s
            model = parent_object.profile['objModels'].select { |v| v.include?('afmodel') }
            puts "Pid #{doc.pid}, parent_id:#{parent_pid}, type:#{model.inspect}"
            return 'Unknown' if model.empty?
            model.first.split(':')[2]
          end
        else
          obj.parent_type = obj.af_model
        end
        obj.save!
      rescue Exception => e
        @exceptions << e.to_s
      end
    end
    unless @exceptions.empty?
      $stderr.puts(@exceptions.join("\n"))
      logger.error(@exceptions.join("\n"))
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

UpdateParentType.update_parent_type
