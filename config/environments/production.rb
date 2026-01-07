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
  config.assets.compile = false   # should be false for precompiled assets
  config.assets.digest = true
  config.assets.version = "1.0"


  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :s3

  # SSL configuration - set via environment variables for manual deployment
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "false") == "true"
  config.force_ssl = ENV.fetch("FORCE_SSL", "false") == "true"

  # Set default URL options for URL generation
  Rails.application.routes.default_url_options = { host: ENV.fetch("HOST", "localhost") }

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT)) # Wrap a standard Logger


  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :solid_queue
  # config.solid_queue.connects_to = { database: { writing: :queue } }

  # Email delivery configuration - using letter_opener for now
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("HOST", "localhost") }

  # Mailtrap SMTP settings (commented out - using letter_opener for now)
  # config.action_mailer.smtp_settings = {
  #   user_name: "f08f0eb24d9514",
  #   password: "f8b601a5a06762",
  #   address: "sandbox.smtp.mailtrap.io",
  #   host: "sandbox.smtp.mailtrap.io",
  #   port: "2525",
  #   authentication: :login
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  config.action_mailer.smtp_settings = {
    user_name: "f08f0eb24d9514",
    password: "f8b601a5a06762",
    address: "sandbox.smtp.mailtrap.io",
    host: "sandbox.smtp.mailtrap.io",
    port: "2525",
    authentication: :login
  }

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
