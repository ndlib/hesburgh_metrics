require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module HesburghMetrics
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    [
      'services'
    ].each do |concept|
      config.autoload_paths << Rails.root.join("app/#{concept}")
    end

    config.generators do |g|
      g.assets = false
      g.helper = false

      g.test_framework :rspec,
                       fixtures: false,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false,
                       controller_specs: false,
                       request_specs: false
    end

    SMTP_CONFIG = YAML.load_file(Rails.root.join("config/smtp_config.yml")).fetch(Rails.env)

    config.action_mailer.delivery_method = SMTP_CONFIG['smtp_delivery_method'].to_sym
    config.action_mailer.smtp_settings = {
        address:              SMTP_CONFIG['smtp_host'],
        port:                 SMTP_CONFIG['smtp_port'],
        domain:               SMTP_CONFIG['smtp_domain'],
        user_name:            SMTP_CONFIG['smtp_user_name'],
        password:             SMTP_CONFIG['smtp_password'],
        authentication:       SMTP_CONFIG['smtp_authentication_type'],
        enable_starttls_auto: SMTP_CONFIG['smtp_enable_starttls_auto']
    }
  end
end
