require 'erb'

# Create Metrics Report for given dates
class MetricsReport
  # Helper class to store report details
  class MetricsDetail
    attr_reader :report_start_date, :report_end_date, :fedora_count,
                :fedora_size, :storage, :count_by_mime_type, :bytes_by_mime_type
    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
      @storage = {}
      @count_by_mime_type={}
      @bytes_by_mime_type={}
    end
  end

  STORAGE_TYPES = %w(Fedora Bendo).freeze

  attr_reader :metrics, :exceptions, :filename

  def initialize(report_start_date, report_end_date)
    @exceptions = []
    @metrics = MetricsDetail.new(report_start_date, report_end_date)
    @filename = "CurateND-report-#{report_start_date}-through-#{report_end_date}.html"
    @template = Rails.root.join('app', 'templates', 'periodic_metrics.html.erb').read
  end

  def generate_report
    # Storage Information
    begin
      STORAGE_TYPES.each do |storage_type|
        storage_information_for(storage_type)
      end
      save!
    rescue StandardError => e
      @exceptions << e.inspect
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
    storage = CurateStorageDetail.where(storage_type: storage_type)
                                 .where('harvest_date <= :as_of', as_of: metrics.report_end_date).last
    metrics.storage[storage_type] = ReportingStorageDetail.new(count: storage.object_count, size: storage.object_bytes) if storage.present?
  end

  def gf_by_mime_type
    gf_by_mime_type = FedoraObject.generic_files(as_of: metrics.report_end_date, group: 'mime_type')
    gf_by_mime_type.each { |m, records|  @metrics.bytes_by_mime_type[m] = records.map(&:bytes).sum}
    gf_by_mime_type.each { |m, records|  @metrics.count_by_mime_type[m] = records.count}

  end

  def render
    ERB.new(@template, nil, '-').result(binding)
  end

  def save!
    File.open(filename, 'w+') do |f|
      f.write(render)
    end
  end
end
