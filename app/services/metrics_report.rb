require 'erb'
require 'action_view'

# Create Metrics Report for given dates
class MetricsReport
  # Helper class to store report details
  class MetricsDetail
    attr_reader :report_start_date, :report_end_date, :fedora_count,
                :fedora_size, :storage, :generic_files_by_holding

    attr_accessor :items_added_count, :items_modified_count, :obj_by_curate_nd_type,
                  :obj_by_administrative_unit, :obj_by_academic_status, :administrative_units_count

    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
      @storage = {}
      @generic_files_by_holding = []
      @administrative_units_count = 0
      @obj_by_curate_nd_type = {}
      @obj_by_administrative_unit = []
    end
  end

  STORAGE_TYPES = %w(Fedora Bendo).freeze
  HOLDING_TYPES = %w(mimetype access_rights).freeze
  ACCESS_RIGHTS = %w(public local embargo private).freeze
  REPORTING_AF_MODELS = %w(Article Audio Dataset Document Etd FindingAid GenericFile Image OsfArchive SeniorThesis).freeze

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
      holding_object_counts
      HOLDING_TYPES.each do |holding_type|
        generic_files_for(holding_type)
      end
      objects_by_model_access_rights
      build_nested_administrative_units
      objects_by_academic_status
      save!
    rescue StandardError => e
      @exceptions << e
    end
    report_any_exceptions
  end

  # get all the count for administrative unit and present them hierarchical order
  # with department wide count and total count
  def report_administrative_unit_as_html(unit = metrics.obj_by_administrative_unit, html = "")
    unit.each do |unit_name, count_by_administrative_unit|
      # if given administrative_unit_hash is department hash, add department name and total count
      if count_by_administrative_unit.is_a?(Hash)
        count_by_department = count_by_administrative_unit.values
        metrics.administrative_units_count = metrics.administrative_units_count + count_by_department.sum
        html << "<tr class=department>  <td>#{unit_name}</td>  <td>#{count_by_department.sum}</td> </tr> "
        report_administrative_unit_as_html(count_by_administrative_unit, html = html)
      else
        html << "<tr>  <td>#{unit_name}</td> <td>#{count_by_administrative_unit}</td> </tr> "
      end
    end
    ApplicationController.helpers.safe_join([html.html_safe])
  end

  def report_any_exceptions
    return unless @exceptions.any?
    @exceptions.each do |error|
      Airbrake.notify_sync(
        'MetricsReportError: ' + error.class.to_s,
        errors: error
      )
    end
  end

  private

  def storage_information_for(storage_type)
    storage = CurateStorageDetail.where(storage_type: storage_type)
                                 .where('harvest_date <= :as_of', as_of: metrics.report_end_date).last
    metrics.storage[storage_type] = ReportingStorageDetail.new(count: storage.object_count, size: storage.object_bytes) if storage.present?
  end

  def holding_object_counts
    metrics.items_added_count = FedoraObject.where('obj_ingest_date <= :end_date AND  obj_ingest_date >= :start_date',
                                                   start_date: metrics.report_start_date, end_date: metrics.report_end_date).count

    metrics.items_modified_count = FedoraObject.where('obj_modified_date <= :end_date AND  obj_modified_date >= :start_date',
                                                      start_date: metrics.report_start_date, end_date: metrics.report_end_date).count
  end

  def generic_files_for(holding_type)
    generic_files_by_type = FedoraObject.generic_files(as_of: metrics.report_end_date, group: holding_type)
    holding_type_objects = {}
    generic_files_by_type.each do |type, objects|
      holding_type_objects[type] = ReportingStorageDetail.new(count: objects.count, size: objects.map(&:bytes).sum)
    end
    metrics.generic_files_by_holding << holding_type_objects
  end

  def objects_by_model_access_rights
    holding_by_nd_access_rights = FedoraObject.group_by_af_model_and_access_rights(as_of: metrics.report_end_date, reporting_models: REPORTING_AF_MODELS)
    metrics.obj_by_curate_nd_type = collect_access_rights(holding_by_nd_access_rights)
  end

  # Create nested hash of access_rights with af_model
  def collect_access_rights(holding_by_nd_access_rights)
    accumulator = {}
    holding_by_nd_access_rights.each do |access_rights_array, object_count|
      accumulator[access_rights_array.first.to_sym] ||= {}
      accumulator[access_rights_array.first.to_sym][access_rights_array.last.to_sym] ||= 0
      accumulator[access_rights_array.first.to_sym][access_rights_array.last.to_sym] += object_count
    end
    accumulator
  end

  def objects_by_academic_status
    metrics.obj_by_academic_status = FedoraObjectAggregationKey.aggregation_by(as_of: metrics.report_end_date,
                                                                               predicate: 'creator#affiliation')
  end

  # Get administrative count as a nested hierarchical hash
  def build_nested_administrative_units
    administrative_unit_array = []
    accumulator = {}
    administrative_units = FedoraObjectAggregationKey.aggregation_by(as_of: metrics.report_end_date,
                                                                     predicate: 'creator#administrative_unit')
    administrative_units.each do |administrative_unit|
      aggregation_keys = administrative_unit.fetch(:aggregation_key).split('::')
      # remove header (University of NotreDame)
      aggregation_keys.shift
      # create nested hash of department with colleges and count
      department_name = aggregation_keys.shift
      count = administrative_unit.fetch(:object_count)
      accumulator[department_name] ||= {}
      # Check if it is department or college level
      if aggregation_keys.present?
        accumulator[department_name][aggregation_keys.shift] = count
      else
        accumulator[department_name] = count
      end
      administrative_unit_array << accumulator
    end
    metrics.obj_by_administrative_unit = administrative_unit_array.reduce(&:deep_merge)
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
