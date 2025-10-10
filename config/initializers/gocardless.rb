# GoCardless configuration
Rails.configuration.gocardless = {
  access_token: Rails.application.credentials.dig(:gocardless, Rails.env.to_sym, :access_token) || ENV["GOCARDLESS_ACCESS_TOKEN"],
  webhook_secret: Rails.application.credentials.dig(:gocardless, Rails.env.to_sym, :webhook_secret) || ENV["GOCARDLESS_WEBHOOK_SECRET"],
  environment: Rails.env.production? ? :live : :sandbox
}

# Configure webhook endpoint
Rails.application.config.after_initialize do
  if Rails.env.development?
    # In development, you might want to use GoCardless webhook testing tools
    # or ngrok for local webhook testing
  end
end
