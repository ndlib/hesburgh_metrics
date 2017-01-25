require 'erb'
class MetricsReport
  class MetricsDetail
    attr_accessor :report_start_date, :report_end_date, :fedora_count, :fedora_size, :storage
    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
    end
  end

  attr_reader :metrics, :exceptions, :filename

  def initialize(report_start_date, report_end_date)
    @exceptions = []
    @metrics = MetricsDetail.new(report_start_date, report_end_date)
    @filename = "CurateND-report-#{report_start_date}-through-#{report_end_date}.html"
    @template = File.read(File.join(Rails.root, 'app', 'templates', 'periodic_metrics.html.erb'))
  end

  def generate_report
    # Storage Information
    @metrics.storage = []
    begin
      %w(Fedora Bendo).map do |type|
        @metrics.storage << storage_information_for(type)
      end
      save!
    rescue StandardError => e
      @exceptions << e.inspect.to_s
    end
    report_any_exceptions
  end

  private

  def report_any_exceptions
    return unless @exceptions.any?
    @exceptions.each do |error_message|
      Airbrake.notify_sync(
        'MetricsReportError',
        errors: error_message
      )
    end
  end

  def storage_information_for(storage_type)
    h = {}
    storage = CurateStorageDetail.where(harvest_date: metrics.report_end_date, storage_type: storage_type).last
    h[storage_type] = { count: storage.object_count, size: storage.object_bytes } if storage.present?
    h
  end

  def render
    ERB.new(@template).result(binding)
  end

  def save!
    File.open(filename, 'w+') do |f|
      f.write(render)
    end
  end
end
