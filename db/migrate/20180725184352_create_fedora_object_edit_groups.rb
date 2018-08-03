class CreateFedoraObjectEditGroups < ActiveRecord::Migration
  def change
    create_table :fedora_object_edit_groups do |t|
      t.belongs_to :fedora_object, index: true, foreign_key: true, null: false
      t.string :edit_group_pid, index: true, null: false
      t.string :edit_group_name, index: true, null: false

      t.timestamps null: false
    end
  end
end
