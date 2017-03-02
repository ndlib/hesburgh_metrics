class IncreaseFedoraObjectTitleSize < ActiveRecord::Migration
  def change
    change_table('fedora_objects') do |t|
      t.change :title, :text, limit: 2_000
    end
  end
end
