require 'erb'

# Create Metrics Report for given dates
class MetricsReport
  # Helper class to store report details
  class MetricsDetail
    attr_reader :report_start_date, :report_end_date, :fedora_count,
                :fedora_size, :storage, :gf_by_holding_type, :obj_by_curate_nd_type

    attr_accessor :items_added_count, :items_modified_count

    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
      @storage = {}
      @gf_by_holding_type=[]
      @obj_by_curate_nd_type=[]
      #@items_added_count = 0
      #@items_modified_count = 0
    end
  end

  STORAGE_TYPES = %w(Fedora Bendo).freeze
  HOLDING_TYPES = %w(mimetype access_rights).freeze
  ACCESS_RIGHTS = %w(public local embargo private).freeze
  REPORTING_AF_MODELS = %w(Article Audio Document Etd GenericFile).freeze

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
      # Holding Information
      get_object_counts
      HOLDING_TYPES.each do |holding_type|
        gf_info_for(holding_type)
      end
      objects_by_model_access_rights
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

  def get_object_counts
    metrics.items_added_count = FedoraObject.where('obj_ingest_date <= :end_date AND  obj_ingest_date >= :start_date',
                                                   start_date: metrics.report_start_date, end_date: metrics.report_end_date).count

    metrics.items_modified_count = FedoraObject.where('obj_modified_date <= :end_date AND  obj_modified_date >= :start_date',
                                                      start_date: metrics.report_start_date, end_date: metrics.report_end_date).count
  end

  def gf_info_for(holding_type)
    gf_by_type = FedoraObject.generic_files(as_of: metrics.report_end_date, group: holding_type)
    holding_type_objects = {}
    gf_by_type.each do |type, objects|
      holding_type_objects[type] = ReportingStorageDetail.new(count: objects.count, size: objects.map(&:bytes).sum)
    end
    metrics.gf_by_holding_type << holding_type_objects
  end

  def objects_by_model_access_rights
    holding_by_nd_access_rights = FedoraObject.where('obj_modified_date <= :as_of', as_of: Date.today)
                                              .where('af_model in (:af_model_array)', af_model_array: REPORTING_AF_MODELS)
                                              .group(:af_model).group(:access_rights).count
    holding_by_nd_access_rights.each do |access_rights_array, count|
      metrics.obj_by_curate_nd_type << access_rights_array.reverse.inject(count) { |count, type| { type.to_sym => count } }
    end
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