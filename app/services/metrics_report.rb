require 'erb'
class MetricsReport

  class MetricsDetail
    attr_accessor :report_start_date, :report_end_date, :fedora_count, :fedora_size
    def initialize(report_start_date,report_end_date )
      @report_start_date = report_start_date
      @report_end_date = report_end_date
    end
  end

  attr_reader :metrics, :exceptions, :fedora, :filename

  def initialize(report_start_date, report_end_date)
    @exceptions = []
    @metrics = MetricsDetail.new(report_start_date, report_end_date)
    @fedora = "Fedora"
    @filename = "CurateND-report-#{report_start_date}-through-#{report_end_date}.md"
    @template = File.read(File.join(Rails.root, 'app','templates','periodic_metrics.txt.erb'))
    fedora_storage_information
  end

  def fedora_storage_information
    metrics.fedora_count = CurateStorageDetail.where(harvest_date: metrics.report_end_date, storage_type: fedora).last.object_count
    metrics.fedora_size = CurateStorageDetail.where(harvest_date: metrics.report_end_date, storage_type: fedora).last.object_bytes
  end


  def render
    ERB.new(@template).result( binding )
  end

  def save
    File.open(filename, "w+") do |f|
      f.write(render)
    end
  end

end