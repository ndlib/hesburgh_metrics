class CreateFedoraObjectAggregationKeys < ActiveRecord::Migration
  def change
    create_table :fedora_object_aggregation_keys do |t|
      t.belongs_to :fedora_object, index: true, foreign_key: true, null: false
      t.string :aggregation_key, index: true, null: false

      t.timestamps null: false
    end
  end
end
