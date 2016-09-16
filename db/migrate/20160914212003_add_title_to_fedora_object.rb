class AddTitleToFedoraObject < ActiveRecord::Migration
  def change
    add_column :fedora_objects, :title, :string, default: ''
    add_index :fedora_objects, :title
  end
end
