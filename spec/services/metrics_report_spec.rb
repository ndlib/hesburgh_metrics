require 'rails_helper'
require 'rspec-html-matchers'

RSpec.describe MetricsReport do
  include RSpecHtmlMatchers
  let (:start_date) { Date.today - 7 }
  let (:end_date) { Date.today }
  let(:report) { described_class.new(start_date, end_date) }

  let(:mock_academic_status) do
    [ {aggregation_key: "Faculty", object_count: 4}, {aggregation_key: "Staff", object_count: 2}]
  end

  let (:mock_administrative_unit_hash) do
    [ { aggregation_key: "University of Notre Dame::College of Arts and Letters::Art, Art History, and Design", object_count: 2},
      { aggregation_key: "University of Notre Dame::College of Arts and Letters::Music", object_count: 1},
      { aggregation_key: "University of Notre Dame::College of Science::Applied and Computational Mathematics and Statistics", object_count: 4}
    ]
  end

  subject { report.generate_report }

  context '#generate_report' do

    before do
      CurateStorageDetail.create(harvest_date: end_date, storage_type: 'Fedora',
                                 object_count: 100, object_bytes: 123456)
      CurateStorageDetail.create(harvest_date: end_date, storage_type: 'Bendo',
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
    before do
      FedoraObject.create(pid: 'parent_pid1', af_model: 'SeniorThesis', resource_type: 'SeniorThesis',
                          mimetype: '', bytes: 0, parent_pid: 'SeniorThesis', obj_ingest_date: end_date,
                          obj_modified_date: end_date, access_rights: 'public', title:'SeniorThesis title')
      FedoraObject.create(pid: 'parent_pid2', af_model: 'SeniorThesis', resource_type: 'SeniorThesis',
                          mimetype: '', bytes: 0, parent_pid: 'SeniorThesis', obj_ingest_date: end_date,
                          obj_modified_date: end_date, access_rights: 'local', title:'SeniorThesis2 title')
      FedoraObject.create(pid: 'generic_file_pid1', af_model: 'GenericFile', resource_type: 'GenericFile',
                          mimetype: 'mimetype1', bytes: 1234, parent_pid: 'parent_pid1', obj_ingest_date: end_date,
                          obj_modified_date: end_date, access_rights: 'public', title:'Some title')
      FedoraObject.create(pid: 'generic_file_pid2', af_model: 'GenericFile', resource_type: 'GenericFile',
                          mimetype: 'mimetype1', bytes: 1234, parent_pid: 'parent_pid2', obj_ingest_date: end_date,
                          obj_modified_date: end_date, access_rights: 'local', title:'Some title')


    end
    it 'get count and size for generic_files by mime_type' do
      subject
      expect(report.metrics.generic_files_by_holding.count).to eq(2)
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
        "College of Science"=>{"Applied and Computational Mathematics and Statistics"=>4}
      }
    end
    it 'get access rights count for all af_model' do
      FedoraObjectAggregationKey.stub(:aggregation_by)
                                .with({as_of: end_date, predicate: 'creator#administrative_unit'}) do |arg|
                                  mock_administrative_unit_hash
      end
      FedoraObjectAggregationKey.stub(:aggregation_by)
                                .with({as_of: end_date, predicate: 'creator#affiliation'}) do |arg|
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
