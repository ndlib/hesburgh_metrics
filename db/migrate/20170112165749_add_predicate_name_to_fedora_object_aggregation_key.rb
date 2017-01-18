class AddPredicateNameToFedoraObjectAggregationKey < ActiveRecord::Migration
  def change
    add_column :fedora_object_aggregation_keys, :predicate_name, :string, null: false
    add_index :fedora_object_aggregation_keys, :predicate_name
  end
end
