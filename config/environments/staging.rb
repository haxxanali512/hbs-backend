require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false
  config.require_master_key = true

  # Enable serving static files from the `/public` folder
  config.public_file_server.enabled = ENV.fetch("RAILS_SERVE_STATIC_FILES", "true") == "true"

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Use harmony mode for ES6+
  config.assets.compile = false
  config.assets.digest = true
  config.assets.version = "1.0"

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :s3

  # SSL configuration - set via environment variables for manual deployment
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "false") == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "false") == "true"

  # Set default URL options for URL generation (domain for links in mail, etc.)
  Rails.application.routes.default_url_options = { host: ENV.fetch("DOMAIN", "staging.example.com") }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))

  # Staging can use a more verbose log level if needed.
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [ :id ]

  # Email delivery - Mailtrap (or SMTP) for staging
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: ENV.fetch("DOMAIN", "staging.example.com") }
  config.action_mailer.default_options = { from: ENV.fetch("MAIL_FROM", "admin@holisticbusinesssolutions.com") }

  config.action_mailer.smtp_settings = {
    user_name: ENV.fetch("SMTP_USER_NAME", "f08f0eb24d9514"),
    password: ENV.fetch("SMTP_PASSWORD", "f8b601a5a06762"),
    address: ENV.fetch("SMTP_ADDRESS", "sandbox.smtp.mailtrap.io"),
    host: ENV.fetch("SMTP_HOST", "sandbox.smtp.mailtrap.io"),
    port: ENV.fetch("SMTP_PORT", "2525"),
    authentication: :login
  }
end
