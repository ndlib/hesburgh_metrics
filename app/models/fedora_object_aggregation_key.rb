# Value object for storing storing Fedora identifiers
class FedoraObjectAggregationKey < ActiveRecord::Base
  belongs_to :fedora_object

  def self.aggregation_by(options = {})
    sql = "select b.aggregation_key as aggregation_key, count(b.fedora_object_id) as object_count from #{quoted_table_name} b
            INNER JOIN #{FedoraObject.quoted_table_name} a on a.id = b.fedora_object_id
            where b.predicate_name= ?
            and a.obj_modified_date <= ?
            group by aggregation_key"
    predicate_name = options.fetch(:predicate)
    modified_date = options.fetch(:as_of)
    FedoraObjectAggregationKey.find_by_sql([sql, predicate_name, modified_date]).map { |aggregation| aggregation.attributes.symbolize_keys }
  end
end
