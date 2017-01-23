class CreateFedoraObjects < ActiveRecord::Migration
  def change
    create_table :fedora_objects do |t|
      t.string :pid, index: true, null: false
      t.string :af_model, index: true, null: false
      t.string :resource_type, index: true, null: false
      t.string :mimetype, index: true, null: false
      t.integer :bytes, limit: 8, null: false
      t.string :parent_pid, index: true, null: false
      t.datetime :obj_ingest_date, index: true, null: false
      t.datetime :obj_modified_date, index: true, null: false
      t.string :access_rights, index: true, null: false

      t.timestamps null: false
    end
  end
end
