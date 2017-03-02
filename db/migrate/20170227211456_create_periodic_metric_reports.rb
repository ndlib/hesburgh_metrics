class CreatePeriodicMetricReports < ActiveRecord::Migration
  def change
    create_table :periodic_metric_reports do |t|
      t.string :filename, default: ''
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.text :content
      t.timestamps null: false
    end
  end
end
