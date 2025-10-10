# Stripe configuration
Rails.configuration.stripe = {
  publishable_key: Rails.application.credentials.dig(:stripe, Rails.env.to_sym, :publishable_key) || ENV["STRIPE_PUBLISHABLE_KEY"],
  secret_key: Rails.application.credentials.dig(:stripe, Rails.env.to_sym, :secret_key) || ENV["STRIPE_SECRET_KEY"],
  webhook_secret: Rails.application.credentials.dig(:stripe, Rails.env.to_sym, :webhook_secret) || ENV["STRIPE_WEBHOOK_SECRET"]
}

# Set the API key for Stripe
Stripe.api_key = Rails.configuration.stripe[:secret_key]

# Configure Stripe webhook endpoint
Rails.application.config.after_initialize do
  if Rails.env.development?
    # In development, you might want to use Stripe CLI for webhook testing
    # stripe listen --forward-to localhost:3000/stripe/webhook
  end
end
