class CreateFedoraAccessEvents < ActiveRecord::Migration
  def change
    create_table :fedora_access_events do |t|
      t.string :event, index: true, null: false
      t.string :pid, index: true, null: false
      t.string :location, index: true, null: false
      t.datetime :event_time, index: true, null: false
      t.string :agent, index: true, null: false

      t.timestamps null: false
    end
  end
end
