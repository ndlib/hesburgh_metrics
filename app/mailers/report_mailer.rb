# This class is responsible for creating/delivering email
class ReportMailer < ActionMailer::Base
  def email(report)
    mail from: default_sender,
         to: recipients_list,
         subject: subject(report),
         content_type: 'text/html; charset=UTF-8',
         body: report.content
  end

  private

  def subject(report)
    "CurateND Metrics Report: #{report.start_date} Through #{report.end_date} - [#{Rails.env}]"
  end

  def recipients_list
    @list ||= Array.wrap(ENV.fetch('METRICS_REPORT_RECIPIENT'))
    @list
  end

  def default_sender
    ENV.fetch('METRICS_REPORT_SENDER')
  end
end
