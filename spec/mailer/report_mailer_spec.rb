require 'rails_helper'

RSpec.describe ReportMailer do
  before do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    allow(report).to receive(:persisted?).and_return(true)
    allow(ENV).to receive(:fetch).with("METRICS_REPORT_SENDER").and_return("noreply@nd.edu")
    allow(ENV).to receive(:fetch).with("METRICS_REPORT_RECIPIENT").and_return("bogus@bogus.com")
  end
  after do
    ActionMailer::Base.deliveries.clear
  end

  let(:report) { PeriodicMetricReport.new(id: '123', start_date: Date.today-7, end_date:Date.today, content:'bogus content') }
  let(:mail) { ReportMailer.email(report) }

  it 'renders the subject' do
    expect(mail.subject).to eql("CurateND Metrics Report: #{report.start_date} Through #{report.end_date} - [#{Rails.env}]")
  end

  it 'renders report content in email' do
    expect(mail.body).to match(report.content)
  end

  it 'renders default sender email' do
    expect(mail.from).to eql(['noreply@nd.edu'])
  end

end

