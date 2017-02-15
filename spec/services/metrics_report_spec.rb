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

  subject { report.generate_report }

  context '#generate_report' do

    before do
      CurateStorageDetail.create(harvest_date: report_end_date, storage_type: 'Fedora',
                                 object_count: 100, object_bytes: 123456)
      CurateStorageDetail.create(harvest_date: report_end_date, storage_type: 'Bendo',
                                 object_count: 10, object_bytes: 1234)
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
  end

  context '#generic_files_for' do
    let(:mock_group_by_access_rights) do
      { "public"=> [double(pid: "some pid", mimetype: "application/pdf", bytes: 14, access_rights: "public")],
        "local"=> [double(pid: "some pid", mimetype: "application/pdf", bytes: 14, access_rights: "local")]
      }
    end
    let(:mock_group_by_mime_type) do
      {  "mimetype1"=> [double(pid: "some pid", mimetype: "mimetype1", bytes: 14, access_rights: "local")],
         "mimetype2"=> [double(pid: "some pid", mimetype: "mimetype2", bytes: 14, access_rights: "public")]
      }
    end
    it 'get count and size for generic_files by mime_type', functional: true do
      FedoraObject.stub(:generic_files).with({as_of: report_end_date, group: 'mimetype'}) do |arg|
        mock_group_by_mime_type
      end
      FedoraObject.stub(:generic_files).with({as_of: report_end_date, group: 'access_rights'}) do |arg|
        mock_group_by_access_rights
      end
      expect do
        subject
      end.to change { report.metrics.generic_files_by_holding.count }.by(2)
      expect(report.metrics.generic_files_by_holding.fetch("mimetype").keys).to eq(['mimetype1','mimetype2'])
      expect(report.metrics.generic_files_by_holding.fetch("access_rights").keys).to eq(['public', 'local'])
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
        "School of Architecture"=>4
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
        with_tag('td', text: 'Art, Art History, and Design')
        with_tag('td', text: '2')
        with_tag('td', text: 'Music')
        with_tag('td', text: '1')
        with_tag('td', text: 'Applied and Computational Mathematics and Statistics')
        with_tag('td', text: '4')
      end
    end

  end

end
