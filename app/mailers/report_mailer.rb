# This class is responsible for creating/delivering email
class ReportMailer < ActionMailer::Base

  def notify(report)
    mail from: sender_email,
         to: recipients_list,
         subject: subject(report),
         content_type: 'text/html; charset=UTF-8',
         body: report.content
  end

  private

  def subject( report )
    "CurateND Metrics Report: #{report.start_date} Through #{report.end_date} - [#{Rails.env}]"
  end

  def recipients_list
    @list ||= Array.wrap(ENV.fetch('METRICS_REPORT_RECIPIENT'))
    return @list
  end

  def sender_email
    ENV.fetch('METRICS_REPORT_SENDER').blank? ? default_sender : ENV.fetch('METRICS_REPORT_SENDER')
  end

  def default_sender
    @sender ||= YAML.load(File.open(File.join(Rails.root, "config/smtp_config.yml")))
    return @sender[Rails.env]["smtp_user_name"]
  end
end
