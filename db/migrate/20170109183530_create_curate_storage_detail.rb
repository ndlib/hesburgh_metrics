class CreateCurateStorageDetail < ActiveRecord::Migration
  def change
    create_table :curate_storage_details do |t|
      t.string :storage_type, index: true, null: false
      t.integer :object_count, index: true, null: false
      t.integer :object_bytes, null: false
      t.date :harvest_date, index: true, null: false

      t.timestamps null: false
    end
  end
end
