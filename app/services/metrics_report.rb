require 'erb'
require 'action_view'

# Create Metrics Report for given dates
class MetricsReport
  # Helper class to store report details
  class MetricsDetail
    attr_reader :report_start_date, :report_end_date, :fedora_count,
                :fedora_size, :storage, :generic_files_by_holding

    attr_accessor :items_added_count, :items_modified_count, :obj_by_curate_nd_type,
                  :obj_by_administrative_unit, :obj_by_academic_status, :administrative_units_count,
                  :top_download_items, :top_viewed_items, :item_usage_by_resource_type_events, :location_usage

    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
      @storage = {}
      @generic_files_by_holding = {}
      @administrative_units_count = 0
      @obj_by_curate_nd_type = {}
      @obj_by_administrative_unit = []
      @location_usage = {}
    end
  end

  STORAGE_TYPES = %w(Fedora Bendo).freeze
  HOLDING_TYPES = %w(mimetype access_rights).freeze
  ACCESS_RIGHTS = %w(public local embargo private).freeze
  REPORTING_AF_MODELS = %w(Article Audio Dataset Document Etd FindingAid GenericFile Image OsfArchive SeniorThesis).freeze

  attr_reader :metrics, :exceptions

  def initialize(report_start_date, report_end_date)
    @exceptions = []
    @metrics = MetricsDetail.new(report_start_date, report_end_date)
    @template = Rails.root.join('app', 'templates', 'periodic_metrics.html.erb').read
  end

  def generate_report
    # Storage Information
    STORAGE_TYPES.each do |storage_type|
      storage_information_for(storage_type)
    end
    # Holding Information
    holding_object_counts
    generic_files
    objects_by_model_access_rights
    build_nested_administrative_units
    objects_by_academic_status
    # Usage Information
    build_usage_by_resource
    build_usage_by_location
    metrics.top_viewed_items = FedoraAccessEvent.top_viewed_objects
    metrics.top_download_items = FedoraAccessEvent.top_downloaded_objects
    # Save report to database and send email
    save!
  rescue StandardError => e
    @exceptions << "Error: generate_report.  Error: #{e.backtrace.join("\n")}"
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
        html << "<tr class=department>  <td>#{unit_name}</td>  <td align=\"right\">#{count_by_department.sum}</td> </tr> "
        report_administrative_unit_as_html(count_by_administrative_unit, html = html)
      else
        html << "<tr>  <td>&nbsp &nbsp &nbsp #{unit_name}</td> <td align=\"right\">#{count_by_administrative_unit}</td> </tr> "
      end
    end
    ApplicationController.helpers.safe_join([html.html_safe])
  end

  GIGABYTE = 10.0**9
  def bytes_to_gb(bytes)
    if bytes.zero?
      "0"
    elsif bytes < 500_000
      "< 0.001 GB"
    else
      size = (bytes / GIGABYTE).round(3)
      "#{size} GB"
    end
  end

  private

  def report_any_exceptions
    return unless @exceptions.any?
    @exceptions.each do |error|
      Airbrake.notify_sync(
        'MetricsReportError: ' + error.class.to_s,
        errors: error
      )
    end
  end

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

  def generic_files
    HOLDING_TYPES.each do |holding_type|
      method_name = "generic_files_by_#{holding_type}".to_sym
      if FedoraObject.respond_to?(method_name)
        generic_files_by_type = FedoraObject.send(method_name, as_of: metrics.report_end_date, reporting_models: REPORTING_AF_MODELS)
        holding_type_objects = {}
        generic_files_by_type.each do |fedora_object|
          holding_type_objects[fedora_object.type] = ReportingStorageDetail.new(count: fedora_object.pid_count, size: fedora_object.total_bytes)
        end
        metrics.generic_files_by_holding[holding_type] = holding_type_objects
      else
        @exceptions << "Error: FedoraObject Undefine Methods #{method_name} to get generic_files"
      end
    end
  end

  def objects_by_model_access_rights
    holding_by_nd_access_rights = FedoraObject.group_by_af_model_and_access_rights(as_of: metrics.report_end_date, reporting_models: REPORTING_AF_MODELS)
    metrics.obj_by_curate_nd_type = collect_access_rights(holding_by_nd_access_rights)
  end

  # Create nested hash of access_rights with af_model
  def collect_access_rights(holding_by_nd_access_rights)
    accumulator = {}
    holding_by_nd_access_rights.each do |access_rights_array, object_count|
      model_key = access_rights_array.first.to_sym
      accumulator[model_key] ||= {}
      rights_key = access_rights_array.last
      rights_key = rights_key.include?("embargo") ? "embargo".to_sym : rights_key.to_sym
      accumulator[model_key][rights_key] ||= 0
      accumulator[model_key][rights_key] += object_count
    end
    accumulator
  end

  # Create nested hash of access_rights with resource
  def build_usage_by_resource
    usage_by_model_event = FedoraAccessEvent.item_usage_by_type(start_date: metrics.report_start_date, end_date: metrics.report_end_date)
    accumulator = {}
    usage_by_model_event.each do |fedora_object|
      accumulator[fedora_object.item_type.to_sym] ||= {}
      accumulator[fedora_object.item_type.to_sym][fedora_object.event.to_sym] ||= 0
      accumulator[fedora_object.item_type.to_sym][fedora_object.event.to_sym] += fedora_object.object_count
    end
    metrics.item_usage_by_resource_type_events = accumulator
  end

  def build_usage_by_location
    all_usage = []
    distinct_usage = []
    all_usage << collect_usage("on_campus", FedoraAccessEvent.all_on_campus_usage(start_date: metrics.report_start_date, end_date: metrics.report_end_date))
    all_usage << collect_usage("off_campus", FedoraAccessEvent.all_off_campus_usage(start_date: metrics.report_start_date, end_date: metrics.report_end_date))
    distinct_usage << collect_usage("on_campus", FedoraAccessEvent.distinct_on_campus_usage(start_date: metrics.report_start_date, end_date: metrics.report_end_date))
    distinct_usage << collect_usage("off_campus", FedoraAccessEvent.distinct_off_campus_usage(start_date: metrics.report_start_date, end_date: metrics.report_end_date))
    metrics.location_usage["all"] = all_usage
    metrics.location_usage["distinct"] = distinct_usage
  end

  # Create nested hash of usage with type
  def collect_usage(usage_type, usage_array)
    accumulator = {}
    usage_array.each do |t|
      key = usage_type.to_sym
      accumulator[key] ||= {}
      accumulator[key][t.event.to_sym] ||= 0
      accumulator[key][t.event.to_sym] += t.event_count
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
      college = aggregation_keys.present? ? aggregation_keys.shift : "non-departmental"
      accumulator[department_name][college] ||= 0
      accumulator[department_name][college] += count.to_i
      administrative_unit_array << accumulator
    end
    metrics.obj_by_administrative_unit = administrative_unit_array.reduce(&:deep_merge)
  end

  def render
    ERB.new(@template, nil, '-').result(binding)
  end

  def save!
    report = PeriodicMetricReport.find_or_initialize_by(start_date: metrics.report_start_date,
                                                        end_date: metrics.report_end_date)
    report.update!(
      filename: filename,
      content: render
    )
    send_report(report.id)
    filename = "CurateND-report-#{metrics.report_start_date}-through-#{metrics.report_end_date}.html"
    File.open(filename, 'w+') do |f|
      f.write(render)
    end
  end

  def send_report(report_id)
    report = PeriodicMetricReport.find(report_id)
    ReportMailer.email(report).deliver_now
  end
end
