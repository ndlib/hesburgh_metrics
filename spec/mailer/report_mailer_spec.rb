require 'rails_helper'

RSpec.describe ReportMailer do
  before do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
    allow(report).to receive(:persisted?).and_return(true)
  end
  after do
    ActionMailer::Base.deliveries.clear
  end

  let(:report) { PeriodicMetricReport.new(id: '123', start_date: Date.today-7, end_date:Date.today, content:'bogus content') }
  let(:mail) { ReportMailer.email(report) }

  context 'renders the subject' do
    it 'renders subject with env for non-production' do
      expect(mail.subject).to eql("[#{Rails.env}] CurateND Metrics Report: #{report.start_date} Through #{report.end_date}")
    end

    it 'renders subject for production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(mail.subject).to eql("CurateND Metrics Report: #{report.start_date} Through #{report.end_date}")
    end
  end

  it 'renders report content in email' do
    expect(mail.body).to match(report.content)
  end

  it 'renders default sender email' do
    expect(mail.from).to eql(['no-reply@nd.edu'])
  end

end

