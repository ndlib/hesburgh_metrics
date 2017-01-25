class AddParentTypeToFedoraObject < ActiveRecord::Migration
  def change
    add_column :fedora_objects, :parent_type, :string, default: ''
    add_index :fedora_objects, :parent_type
  end
end
