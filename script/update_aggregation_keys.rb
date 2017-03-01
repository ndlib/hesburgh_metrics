# Responsible for extracting academic status for all fedora object
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

  def update_predicate_name_as_administrative_unit
    FedoraObjectAggregationKey.find_each do |obj|
      begin
        obj.update!(predicate_name: 'creator#administrative_unit') if obj.predicate_name.blank?
      rescue Exception => e
        logger.error "Error: updating predicate name as administrative_unit for #{obj.pid}.  Error was #{e.backtrace}"
      end
    end
  end

  def update_academic_status
    @exceptions = []
    @repo = Rubydora.connect url: Figaro.env.fedora_url!, user: Figaro.env.fedora_user!, password: Figaro.env.fedora_password!
    FedoraObject.find_each do |fedora_object|
      begin
        pid = "und:#{fedora_object.pid}"
        predicate_name = "creator#affiliation"
        logger.info "########### Get Academic Status from Fedora for #{pid} ###############"
        doc = @repo.find pid
        agg_key_array = []
        if doc.datastreams.key?('descMetadata')
          # load new aggregation_key agg_key_array
          agg_key_array = parse_triples(doc.datastreams['descMetadata'].content, predicate_name)
        end
        # if there are any aggregation keys now, add or update what is currently stored
        if agg_key_array.any?
          # add any new aggregation keys which don't already exist
          agg_key_array.each do |key|
            next if fedora_object.fedora_object_aggregation_keys.where(predicate_name: predicate_name, aggregation_key: key).present?
            fedora_object.fedora_object_aggregation_keys.create!(predicate_name: predicate_name, aggregation_key: key)
          end
        end
        # destroy any prior aggregation keys which no longer exist
        fedora_object.fedora_object_aggregation_keys.where(predicate_name: predicate_name).each do |aggregation_key|
          fedora_object.fedora_object_aggregation_keys.where(predicate_name: predicate_name).destroy unless agg_key_array.include? aggregation_key
        end
      rescue Exception => e
        logger.error "Error: error update_academic_status for #{fedora_object.pid}.  Error was #{e}"
        @exceptions <<  "Error: error update_academic_status for #{fedora_object.pid}.  Error: #{e}"
      end
    end
    unless @exceptions.empty?
      logger.error @exceptions.join("\n")
    end
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
        @exceptions << "#{e.inspect}"
      end
    end
    data_array
  end
end

def logger
  Rails.logger
end

UpdateParentType.update_predicate_name_as_administrative_unit
UpdateParentType.update_academic_status
