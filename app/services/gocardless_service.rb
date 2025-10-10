class GoCardlessService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :access_token, :string
  attribute :environment, :string, default: "sandbox"

  def initialize(access_token: nil, environment: "sandbox")
    @access_token = access_token || Rails.application.credentials.dig(:gocardless, environment.to_sym, :access_token)
    @environment = environment
    super()
  end

  # Create GoCardless client
  def create_client
    GoCardlessPro::Client.new(
      access_token: @access_token,
      environment: @environment.to_sym
    )
  end

  # Get all customers
  def fetch_customers(limit: 100)
    begin
      client = create_client
      customers = client.customers.list(
        limit: limit
      )

      {
        success: true,
        customers: customers.records.map { |customer| format_customer(customer) },
        has_more: customers.after.present?
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        customers: []
      }
    end
  end

  # Create a customer
  def create_customer(params)
    begin
      client = create_client
      customer = client.customers.create(
        params: {
          email: params[:email],
          given_name: params[:given_name],
          family_name: params[:family_name],
          address_line1: params[:address_line1],
          city: params[:city],
          postal_code: params[:postal_code],
          country_code: params[:country_code] || "GB",
          metadata: params[:metadata] || {}
        }
      )

      {
        success: true,
        customer: format_customer(customer)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        customer: nil
      }
    end
  end

  # Get customer by ID
  def fetch_customer(customer_id)
    begin
      client = create_client
      customer = client.customers.get(customer_id)
      {
        success: true,
        customer: format_customer(customer)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        customer: nil
      }
    end
  end

  # Create a mandate (authorization for direct debit)
  def create_mandate(params)
    begin
      client = create_client
      mandate = client.mandates.create(
        params: {
          links: {
            customer: params[:customer_id]
          },
          scheme: params[:scheme] || "bacs",
          metadata: params[:metadata] || {}
        }
      )

      {
        success: true,
        mandate: format_mandate(mandate)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        mandate: nil
      }
    end
  end

  # Get mandate by ID
  def fetch_mandate(mandate_id)
    begin
      client = create_client
      mandate = client.mandates.get(mandate_id)
      {
        success: true,
        mandate: format_mandate(mandate)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        mandate: nil
      }
    end
  end

  # Create a payment
  def create_payment(params)
    begin
      client = create_client
      payment = client.payments.create(
        params: {
          amount: params[:amount], # Amount in pence
          currency: params[:currency] || "GBP",
          links: {
            mandate: params[:mandate_id]
          },
          metadata: params[:metadata] || {}
        }
      )

      {
        success: true,
        payment: format_payment(payment)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        payment: nil
      }
    end
  end

  # Create a subscription
  def create_subscription(params)
    begin
      client = create_client
      subscription = client.subscriptions.create(
        params: {
          amount: params[:amount], # Amount in pence
          currency: params[:currency] || "GBP",
          interval_unit: params[:interval_unit] || "monthly",
          interval: params[:interval] || 1,
          links: {
            mandate: params[:mandate_id]
          },
          metadata: params[:metadata] || {}
        }
      )

      {
        success: true,
        subscription: format_subscription(subscription)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Get subscription by ID
  def fetch_subscription(subscription_id)
    begin
      client = create_client
      subscription = client.subscriptions.get(subscription_id)
      {
        success: true,
        subscription: format_subscription(subscription)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Cancel a subscription
  def cancel_subscription(subscription_id)
    begin
      client = create_client
      subscription = client.subscriptions.cancel(subscription_id)
      {
        success: true,
        subscription: format_subscription(subscription)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        subscription: nil
      }
    end
  end

  # Get all payments for a customer
  def fetch_customer_payments(customer_id, limit: 100)
    begin
      client = create_client
      payments = client.payments.list(
        limit: limit,
        params: {
          customer: customer_id
        }
      )

      {
        success: true,
        payments: payments.records.map { |payment| format_payment(payment) }
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        payments: []
      }
    end
  end

  # Create a redirect flow for customer authorization
  def create_redirect_flow(params)
    begin
      client = create_client
      redirect_flow = client.redirect_flows.create(
        params: {
          description: params[:description] || "Organization billing setup",
          session_token: params[:session_token],
          success_redirect_url: params[:success_redirect_url],
          prefilled_customer: {
            given_name: params[:given_name],
            family_name: params[:family_name],
            email: params[:email]
          },
          metadata: params[:metadata] || {}
        }
      )

      {
        success: true,
        redirect_flow: format_redirect_flow(redirect_flow)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        redirect_flow: nil
      }
    end
  end

  # Complete a redirect flow
  def complete_redirect_flow(redirect_flow_id)
    begin
      client = create_client
      redirect_flow = client.redirect_flows.complete(
        redirect_flow_id,
        params: {}
      )

      {
        success: true,
        redirect_flow: format_redirect_flow(redirect_flow)
      }
    rescue GoCardlessPro::GoCardlessError => e
      {
        success: false,
        error: e.message,
        redirect_flow: nil
      }
    end
  end

  # Handle webhook events
  def handle_webhook(payload, signature)
    begin
      # GoCardless webhook verification
      webhook_endpoint_secret = Rails.application.credentials.dig(:gocardless, @environment.to_sym, :webhook_secret)

      # Verify webhook signature
      expected_signature = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new("sha256"),
        webhook_endpoint_secret,
        payload
      )

      unless Rack::Utils.secure_compare(signature, expected_signature)
        return {
          success: false,
          error: "Invalid signature"
        }
      end

      events = JSON.parse(payload)

      {
        success: true,
        events: events
      }
    rescue JSON::ParserError => e
      {
        success: false,
        error: "Invalid payload: #{e.message}"
      }
    rescue => e
      {
        success: false,
        error: "Webhook processing error: #{e.message}"
      }
    end
  end

  private

  def format_customer(customer)
    {
      id: customer.id,
      email: customer.email,
      given_name: customer.given_name,
      family_name: customer.family_name,
      address_line1: customer.address_line1,
      city: customer.city,
      postal_code: customer.postal_code,
      country_code: customer.country_code,
      created_at: customer.created_at,
      metadata: customer.metadata
    }
  end

  def format_mandate(mandate)
    {
      id: mandate.id,
      status: mandate.status,
      scheme: mandate.scheme,
      created_at: mandate.created_at,
      metadata: mandate.metadata,
      links: mandate.links
    }
  end

  def format_payment(payment)
    {
      id: payment.id,
      amount: payment.amount,
      currency: payment.currency,
      status: payment.status,
      created_at: payment.created_at,
      metadata: payment.metadata,
      links: payment.links
    }
  end

  def format_subscription(subscription)
    {
      id: subscription.id,
      amount: subscription.amount,
      currency: subscription.currency,
      status: subscription.status,
      interval_unit: subscription.interval_unit,
      interval: subscription.interval,
      created_at: subscription.created_at,
      metadata: subscription.metadata,
      links: subscription.links
    }
  end

  def format_redirect_flow(redirect_flow)
    {
      id: redirect_flow.id,
      redirect_url: redirect_flow.redirect_url,
      session_token: redirect_flow.session_token,
      created_at: redirect_flow.created_at,
      metadata: redirect_flow.metadata
    }
  end
end
