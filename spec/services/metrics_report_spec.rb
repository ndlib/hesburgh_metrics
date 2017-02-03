require 'rails_helper'

RSpec.describe MetricsReport do
  context '#generate_report' do
    let (:start_date) { Date.today - 7 }
    let (:end_date) { Date.today }
    let(:report) { described_class.new(start_date, end_date) }
    subject { report.generate_report }

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
end
