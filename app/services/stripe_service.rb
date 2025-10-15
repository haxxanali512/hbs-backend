class StripeService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :api_key, :string
  attribute :environment, :string, default: "test"

  def initialize(api_key: nil, environment: "test")
    @api_key = api_key || Rails.application.credentials.stripe[:secret_key]
    @environment = environment
    super()
  end

  # Configure Stripe with the API key
  def configure_stripe
    Stripe.api_key = @api_key
  end

  # Get all products from Stripe
  def fetch_products(limit: 100, active: true)
    configure_stripe

    begin
      products = Stripe::Product.list(
        limit: limit,
        active: active
      )

      {
        success: true,
        products: products.data.map { |product| format_product(product) },
        has_more: products.has_more
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        products: []
      }
    end
  end

  # Ensure a Stripe Customer exists for the given email; create if missing
  def find_or_create_customer(email:, name: nil, metadata: {})
    configure_stripe

    begin
      existing = Stripe::Customer.list(email: email, limit: 1)
      customer = existing.data.first
      unless customer
        customer = Stripe::Customer.create(
          email: email,
          name: name,
          metadata: metadata
        )
      end

      { success: true, customer: customer }
    rescue Stripe::StripeError => e
      { success: false, error: e.message, customer: nil }
    end
  end

  # Create a SetupIntent to collect and save a payment method for off-session use
  def create_setup_intent(customer_id)
    configure_stripe

    begin
      si = Stripe::SetupIntent.create(
        customer: customer_id,
        usage: "off_session",
        payment_method_types: [ "card" ]
      )
      { success: true, setup_intent: si, client_secret: si.client_secret }
    rescue Stripe::StripeError => e
      { success: false, error: e.message, setup_intent: nil, client_secret: nil }
    end
  end

  # Retrieve a payment method (e.g., to read brand/last4)
  def retrieve_payment_method(payment_method_id)
    configure_stripe

    begin
      pm = Stripe::PaymentMethod.retrieve(payment_method_id)
      { success: true, payment_method: pm }
    rescue Stripe::StripeError => e
      { success: false, error: e.message, payment_method: nil }
    end
  end

  # Set default payment method on customer (for invoices/off-session charges)
  def set_default_payment_method(customer_id, payment_method_id)
    configure_stripe

    begin
      customer = Stripe::Customer.update(
        customer_id,
        invoice_settings: { default_payment_method: payment_method_id }
      )
      { success: true, customer: customer }
    rescue Stripe::StripeError => e
      { success: false, error: e.message, customer: nil }
    end
  end

  # Get a specific product by ID
  def fetch_product(product_id)
    configure_stripe

    begin
      product = Stripe::Product.retrieve(product_id)
      {
        success: true,
        product: format_product(product)
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        product: nil
      }
    end
  end

  # Get prices for a specific product
  def fetch_product_prices(product_id)
    configure_stripe

    begin
      prices = Stripe::Price.list(
        product: product_id,
        active: true
      )

      {
        success: true,
        prices: prices.data.map { |price| format_price(price) }
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        prices: []
      }
    end
  end

  # Create a checkout session
  def create_checkout_session(params)
    configure_stripe

    begin
      session_params = {
        payment_method_types: [ "card" ],
        line_items: params[:line_items],
        mode: params[:mode] || "payment",
        success_url: params[:success_url],
        cancel_url: params[:cancel_url],
        customer_email: params[:customer_email],
        metadata: params[:metadata] || {}
      }

      # Add subscription-specific parameters if mode is subscription
      if params[:mode] == "subscription"
        session_params[:subscription_data] = params[:subscription_data] if params[:subscription_data]
        session_params[:billing_address_collection] = params[:billing_address_collection] || "required"
      end

      session = Stripe::Checkout::Session.create(session_params)

      {
        success: true,
        session_id: session.id,
        session_url: session.url,
        session: session
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        session_id: nil,
        session_url: nil
      }
    end
  end

  # Retrieve a checkout session
  def fetch_checkout_session(session_id)
    configure_stripe

    begin
      session = Stripe::Checkout::Session.retrieve(session_id)
      {
        success: true,
        session: session
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        session: nil
      }
    end
  end

  # Create a customer
  def create_customer(params)
    configure_stripe

    begin
      customer = Stripe::Customer.create(
        email: params[:email],
        name: params[:name],
        metadata: params[:metadata] || {}
      )

      {
        success: true,
        customer: customer
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        customer: nil
      }
    end
  end

  # Create a payment intent for one-time payments
  def create_payment_intent(params)
    configure_stripe

    begin
      payment_intent = Stripe::PaymentIntent.create(
        amount: params[:amount], # Amount in cents
        currency: params[:currency] || "usd",
        customer: params[:customer_id],
        metadata: params[:metadata] || {}
      )

      {
        success: true,
        payment_intent: payment_intent
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        payment_intent: nil
      }
    end
  end

  # Get payment methods for a customer
  def fetch_customer_payment_methods(customer_id)
    configure_stripe

    begin
      payment_methods = Stripe::PaymentMethod.list(
        customer: customer_id,
        type: "card"
      )

      {
        success: true,
        payment_methods: payment_methods.data
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        payment_methods: []
      }
    end
  end

  # Create a subscription
  def create_subscription(params)
    configure_stripe

    begin
      subscription = Stripe::Subscription.create(
        customer: params[:customer_id],
        items: params[:items],
        metadata: params[:metadata] || {}
      )

      {
        success: true,
        subscription: subscription
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Cancel a subscription
  def cancel_subscription(subscription_id)
    configure_stripe

    begin
      subscription = Stripe::Subscription.update(
        subscription_id,
        cancel_at_period_end: true
      )

      {
        success: true,
        subscription: subscription
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Get subscription details
  def fetch_subscription(subscription_id)
    configure_stripe

    begin
      subscription = Stripe::Subscription.retrieve(subscription_id)
      {
        success: true,
        subscription: subscription
      }
    rescue Stripe::StripeError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Handle webhook events
  def handle_webhook(payload, signature)
    configure_stripe

    begin
      event = Stripe::Webhook.construct_event(
        payload,
        signature,
        Rails.application.credentials.dig(:stripe, @environment.to_sym, :webhook_secret)
      )

      {
        success: true,
        event: event
      }
    rescue Stripe::SignatureVerificationError => e
      {
        success: false,
        error: "Invalid signature: #{e.message}"
      }
    rescue JSON::ParserError => e
      {
        success: false,
        error: "Invalid payload: #{e.message}"
      }
    end
  end

  private

  def format_product(product)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      active: product.active,
      created: product.created,
      images: product.images,
      metadata: product.metadata,
      type: product.type,
      url: product.url
    }
  end

  def format_price(price)
    {
      id: price.id,
      product_id: price.product,
      amount: price.unit_amount,
      currency: price.currency,
      type: price.type,
      active: price.active,
      created: price.created,
      metadata: price.metadata,
      recurring: price.recurring ? {
        interval: price.recurring.interval,
        interval_count: price.recurring.interval_count
      } : nil
    }
  end
end
