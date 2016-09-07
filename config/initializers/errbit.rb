Airbrake.configure do |config|
  config.host = Figaro.env.airbrake_host!
  config.project_id = true
  config.project_key = Figaro.env.airbrake_project_key!
  config.environment = Rails.env
end
