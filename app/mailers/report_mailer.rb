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
    subject = "CurateND Metrics Report: #{report.start_date} Through #{report.end_date}"
    return "[#{Rails.env}] #{subject}" unless Rails.env.eql?("production")
    subject
  end

  def recipients_list
    @list ||= Figaro.env.METRICS_REPORT_RECIPIENT!.split(',').map(&:strip)
  end

  def default_sender
    Figaro.env.METRICS_REPORT_SENDER
  end
end
