require 'erb'

# Create Metrics Report for given dates
class MetricsReport
  # Helper class to store report details
  class MetricsDetail
    attr_reader :report_start_date, :report_end_date, :fedora_count,
                :fedora_size, :storage, :gf_by_holding_type, :obj_by_curate_nd_type

    attr_accessor :items_added_count, :items_modified_count,
                  :obj_by_administrative_unit, :obj_by_academic_status, :administrative_units_count

    def initialize(report_start_date, report_end_date)
      @report_start_date = report_start_date
      @report_end_date = report_end_date
      @storage = {}
      @gf_by_holding_type = []
      @obj_by_curate_nd_type = []
      @administrative_units_count = 0
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
      holding_object_counts
      HOLDING_TYPES.each do |holding_type|
        gf_info_for(holding_type)
      end
      objects_by_model_access_rights
      administrative_unit_count
      objects_by_academic_status
      save!
    rescue StandardError => e
      @exceptions << e.inspect
    end
    report_any_exceptions
  end

  def administrative_unit_presenter(_unit = metrics.obj_by_administrative_unit, html = "")
    obj_by_administrative_unit.each do |unit_name, count_by_administrative_unit|
      total_by_dept = 0
      if count_by_administrative_unit.is_a?(Hash)
        count_by_department = count_by_administrative_unit.values
        if count_by_department.all? { |i| i.is_a?(Integer) }
          total_by_dept = count_by_department.sum
          html << "<tr class=department> \n"
          html << "<td> #{unit_name} </td> \n"
          html << "<td> #{total_by_dept} </td>\n"
          html << "</tr> \n"
        end
        metrics.administrative_units_count = metrics.administrative_units_count + total_by_dept
        administrative_unit_presenter(count_by_administrative_unit, html = html)
      else
        html << "<tr> \n"
        html <<  "<td> #{unit_name} </td>\n"
        html <<  "<td> #{count_by_administrative_unit} </td> "
        html << "</tr> \n"
      end
    end
    html.html_safe
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

  def holding_object_counts
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
    holding_by_nd_access_rights = FedoraObject.where('obj_modified_date <= :as_of', as_of: metrics.report_end_date)
                                              .where('af_model in (:af_model_array)', af_model_array: REPORTING_AF_MODELS)
                                              .group(:af_model).group(:access_rights).count
    holding_by_nd_access_rights.each do |access_rights_array, object_count|
      metrics.obj_by_curate_nd_type << access_rights_array.reverse.inject(object_count) { |count, type| { type.to_sym => count } }
    end
  end

  def objects_by_academic_status
    metrics.obj_by_academic_status = FedoraObjectAggregationKey.aggregation_by(as_of: metrics.report_end_date,
                                                                               predicate: 'creator#affiliation')
  end

  def administrative_unit_count
    administrative_unit_array = []
    administrative_units = FedoraObjectAggregationKey.aggregation_by(as_of: metrics.report_end_date,
                                                                     predicate: 'creator#administrative_unit')
    administrative_units.each do |administrative_unit|
      aggregation_keys = administrative_unit.fetch('aggregation_key').split('::')
      administrative_unit_array << aggregation_keys.reverse.inject(administrative_unit.fetch('object_count')) { |object_count, unit_name| { unit_name => object_count } }
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
