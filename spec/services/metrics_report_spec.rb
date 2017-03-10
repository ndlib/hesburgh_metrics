require 'rails_helper'
require 'rspec-html-matchers'

RSpec.describe MetricsReport do
  include RSpecHtmlMatchers
  let (:report_start_date) { Date.today - 7 }
  let (:report_end_date) { Date.today }
  let(:report) { described_class.new(report_start_date, report_end_date) }

  let(:mock_academic_status) do
    [ {aggregation_key: "Faculty", object_count: 4}, {aggregation_key: "Staff", object_count: 2}]
  end

  let (:mock_administrative_unit_hash) do
    [ { aggregation_key: "University of Notre Dame::College of Arts and Letters::Art, Art History, and Design", object_count: 2},
      { aggregation_key: "University of Notre Dame::College of Arts and Letters::Music", object_count: 1},
      { aggregation_key: "University of Notre Dame::College of Science::Applied and Computational Mathematics and Statistics", object_count: 4},
      { aggregation_key: "University of Notre Dame::School of Architecture", object_count: 4}
    ]
  end

  let(:persisted_report) { PeriodicMetricReport.new(id: '123', start_date: Date.today-7, end_date:Date.today, content:'bogus content') }

  subject { report.generate_report }

  context '#generate_report' do

    before do
      CurateStorageDetail.create(harvest_date: report_end_date, storage_type: 'Fedora',
                                 object_count: 100, object_bytes: 123456)
      CurateStorageDetail.create(harvest_date: report_end_date, storage_type: 'Bendo',
                                 object_count: 10, object_bytes: 1234)
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries = []
      allow(persisted_report).to receive(:persisted?).and_return(true)
    end
    after do
      ActionMailer::Base.deliveries.clear
      CurateStorageDetail.delete_all
    end

    it 'generate metrics report for given reporting dates', functional: true do
      subject
      expect(report.metrics.storage.count).to eq(2)
    end

    it 'will report to Airbrake any exceptions encountered' do
      allow(report).to receive(:save!).and_raise(RuntimeError)
      expect(Airbrake).to receive(:notify_sync).and_call_original
      subject
    end

    it '#send_report' do
      subject
      allow(PeriodicMetricReport).to receive(:find).and_return(persisted_report)
      allow(report).to receive(:send_report).and_call_original
      ActionMailer::Base.deliveries.count.should == 1
    end
  end

  context "#report_administrative_unit_as_html" do
    let (:blank_administrative_unit_hash) { {} }
    let (:nested_administrative_unit_hash) do
      {
          "College of Arts and Letters"=>{"Art, Art History, and Design"=>2, "Music"=>1},
          "College of Science"=>{"Applied and Computational Mathematics and Statistics"=>4}
      }
    end
    it "returns blank for administrative unit listing when there is not administrative units" do
      expect(report.report_administrative_unit_as_html).to eq("")
    end

    it "return tabulated administrative unit with count" do
      html = report.report_administrative_unit_as_html(nested_administrative_unit_hash)
      expect(html).to have_tag('tr', :with => { :class => 'department'}) do
        with_tag('td', text: 'College of Arts and Letters')
        with_tag('td', text: '3')
        with_tag('td', text: 'College of Science')
        with_tag('td', text: '4')
      end
      expect(html).to have_tag('tr') do
        with_tag('td', text: '&nbsp &nbsp &nbsp Art, Art History, and Design')
        with_tag('td', text: '2')
        with_tag('td', text: '&nbsp &nbsp &nbsp Music')
        with_tag('td', text: '1')
        with_tag('td', text: '&nbsp &nbsp &nbsp Applied and Computational Mathematics and Statistics')
        with_tag('td', text: '4')
      end
    end
  end

  context "#bytes_to_gb" do
    it 'will return 0 for 0 Bytes' do
      expect(report.bytes_to_gb(0)).to eq("0")
    end
    it 'will return <0.001 GB when it is less than 5MB' do
      expect(report.bytes_to_gb(399956)).to eq('< 0.001 GB')
    end
    it 'will convert to GB for given bytes' do
      expect(report.bytes_to_gb(12354578789)).to eq("12.355 GB")
    end
  end

  context '#generic_files' do
    let(:mock_group_by_access_rights) do
      [
        double(pid_count: "6", total_bytes: 14, type: "public"),
        double(pid_count: "6",  total_bytes: 14, type: "local")
      ]
    end
    let(:mock_group_by_mime_type) do
      [
        double(pid_count: "5", type: "mimetype1", total_bytes: 14),
        double(pid_count: "10", type: "mimetype2", total_bytes: 14)
      ]
    end
    it 'get count and size for generic_files by mime_type', functional: true do
      FedoraObject.stub(:generic_files_by_mimetype).with({as_of: report_end_date,
                                              reporting_models: ["Article", "Audio", "Dataset", "Document", "Etd", "FindingAid", "GenericFile", "Image", "OsfArchive", "SeniorThesis"]}) do |arg|
        mock_group_by_mime_type
      end
      FedoraObject.stub(:generic_files_by_access_rights).with({as_of: report_end_date,
                                              reporting_models:["Article", "Audio", "Dataset", "Document", "Etd", "FindingAid", "GenericFile", "Image", "OsfArchive", "SeniorThesis"]}) do |arg|
        mock_group_by_access_rights
      end
      expect do
        subject
      end.to change { report.metrics.generic_files_by_holding.count }.by(2)
      expect(report.metrics.generic_files_by_holding.fetch("mimetype").keys).to eq(['mimetype1','mimetype2'])
      expect(report.metrics.generic_files_by_holding.fetch("access_rights").keys).to eq(['public', 'local'])
    end
    it "Log exception when not able to collect generic_files for given holding type  " do
      stub_const("MetricsReport::HOLDING_TYPES", %w(bogus))
      MetricsReport::HOLDING_TYPES.should eq(["bogus"])
      expect do
        subject
      end.to change { report.metrics.generic_files_by_holding.count }.by(0)
    end
  end

  context '#collect_access_rights' do
    let(:mock_access_rights) do
      { ["Article", "local"]=>2,
        ["Article", "public"]=>15,
        ["Audio", "public"]=>2,
        ["Dataset", "public"]=>1,
        ["Document", "private"]=>1,
        ["Document", "public"]=>5,
        ["GenericFile", "local"]=>314,
        ["GenericFile", "private"]=>1,
        ["GenericFile", "public"]=>347,
        ["Image", "local"]=>44,
        ["Image", "public"]=>3,
        ["SeniorThesis", "local"]=>1
      }
    end
    it 'get count and size for generic_files by mime_type' do
      allow(FedoraObject).to receive_message_chain(:group_by_af_model_and_access_rights).and_return(mock_access_rights)
      subject
      expect(report.metrics.obj_by_curate_nd_type.fetch(:SeniorThesis)).to eq({local: 1})
      expect(report.metrics.obj_by_curate_nd_type.fetch(:GenericFile)).to eq({local: 314, private: 1, public: 347})
    end
  end

  context '#get academic_status count' do
    let (:nested_administrative_unit_hash) do
      {
        "College of Arts and Letters"=>{"Art, Art History, and Design"=>2, "Music"=>1},
        "College of Science"=>{"Applied and Computational Mathematics and Statistics"=>4},
        "School of Architecture"=>{"non-departmental" =>4}
      }
    end
    it 'get access rights count for all af_model' do
      FedoraObjectAggregationKey.stub(:aggregation_by)
                                .with({as_of: report_end_date, predicate: 'creator#administrative_unit'}) do |arg|
                                  mock_administrative_unit_hash
      end
      FedoraObjectAggregationKey.stub(:aggregation_by)
                                .with({as_of: report_end_date, predicate: 'creator#affiliation'}) do |arg|
                                  mock_academic_status
      end
      subject
      expect(report.metrics.obj_by_academic_status.map{|result| result.fetch(:aggregation_key)}).to eq(["Faculty", "Staff"])
      expect(report.metrics.obj_by_administrative_unit).to eq(nested_administrative_unit_hash)
    end
  end

  context '#build_usage_by_resource' do
    let(:mock_usage_by_resource) do
      [ double(event: "view", item_type:"Article", object_count:2022),
        double(event: "view", item_type:"Audio", object_count:16),
        double(event: "view", item_type:"Collection", object_count:4),
        double(event: "download", item_type:"Dataset", object_count:464),
        double(event: "view", item_type:"Dataset", object_count:2383),
        double(event: "download", item_type:"Document", object_count:470),
        double(event: "view", item_type:"Document", object_count:1753)
      ]
    end
    it 'get event and count by resource type', functional: true do
      FedoraAccessEvent.stub(:item_usage_by_type)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_by_resource
      end
      subject
      expect(report.metrics.item_usage_by_resource_type_events.count).to eq(5)
      expect(report.metrics.item_usage_by_resource_type_events.keys).to eq([:Article, :Audio, :Collection, :Dataset, :Document])
    end
  end

  context '#build_usage_location' do
    let(:resulted_usage_by_location) do
      { "all"=>[ {:on_campus=>{ view: 16, download:123}},
                 {:off_campus=>{view:163, download:10}}],
        "distinct"=>[ {:on_campus=>{view:3, download: 20}},
                      {:off_campus=>{view:16, download:2671}}]
      }
    end
    let(:mock_usage_all_on_campus) do
      [ double(event: "view", event_count:16),
        double(event: "download",  event_count:123)
      ]
    end
    let(:mock_usage_all_off_campus) do
      [ double(event: "view",  event_count:163),
        double(event: "download", event_count:10),
      ]
    end
    let(:mock_usage_distinct_on_campus) do
      [ double(event: "view", event_count:3),
        double(event: "download",  event_count:20)
      ]
    end
    let(:mock_usage_distinct_off_campus) do
      [ double(event: "view",  event_count:16),
        double(event: "download", event_count:2671),
      ]
    end
    it 'get event and count by location (on-campus and off-campus access)', functional: true do
      FedoraAccessEvent.stub(:all_on_campus_usage)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_all_on_campus
      end
      FedoraAccessEvent.stub(:all_off_campus_usage)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_all_off_campus
      end
      FedoraAccessEvent.stub(:distinct_on_campus_usage)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_distinct_on_campus
      end
      FedoraAccessEvent.stub(:distinct_off_campus_usage)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_distinct_off_campus
      end
      subject
      expect(report.metrics.location_usage.keys).to eq(["all", "distinct"])
      expect(report.metrics.location_usage).to eq(resulted_usage_by_location)
    end
  end

  context '#build_usage_by_resource' do
    let(:mock_usage_by_model_event) do
      [ double(event: "view", item_type:"Article", object_count:2022),
        double(event: "view", item_type:"Audio", object_count:16),
        double(event: "view", item_type:"Collection", object_count:4),
        double(event: "download", item_type:"Dataset", object_count:464),
        double(event: "view", item_type:"Dataset", object_count:2383),
        double(event: "download", item_type:"Document", object_count:470),
        double(event: "view", item_type:"Document", object_count:1753)
      ]
    end
    it 'get event and count by resource type', functional: true do
      FedoraAccessEvent.stub(:item_usage_by_type)
      .with({start_date: report_start_date, end_date: report_end_date}) do |arg|
        mock_usage_by_model_event
      end
      subject
      expect(report.metrics.item_usage_by_resource_type_events.count).to eq(5)
      expect(report.metrics.item_usage_by_resource_type_events.keys).to eq([:Article, :Audio, :Collection, :Dataset, :Document])
    end
  end

end
