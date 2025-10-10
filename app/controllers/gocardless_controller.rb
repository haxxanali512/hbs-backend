class GoCardlessController < ApplicationController
  before_action :authenticate_user!
  before_action :set_gocardless_service

  # GET /gocardless/customers
  def customers
    result = @gocardless_service.fetch_customers(limit: params[:limit]&.to_i || 100)

    if result[:success]
      render json: {
        success: true,
        customers: result[:customers],
        has_more: result[:has_more]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/customers
  def create_customer
    customer_params = {
      email: params[:email],
      given_name: params[:given_name],
      family_name: params[:family_name],
      address_line1: params[:address_line1],
      city: params[:city],
      postal_code: params[:postal_code],
      country_code: params[:country_code] || "GB",
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id
      }
    }

    result = @gocardless_service.create_customer(customer_params)

    if result[:success]
      render json: {
        success: true,
        customer: result[:customer]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /gocardless/customers/:id
  def customer
    result = @gocardless_service.fetch_customer(params[:id])

    if result[:success]
      render json: {
        success: true,
        customer: result[:customer]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/redirect_flow
  def create_redirect_flow
    # Generate a unique session token
    session_token = SecureRandom.hex(32)

    redirect_params = {
      description: "Organization billing setup for #{current_user.email}",
      session_token: session_token,
      success_redirect_url: params[:success_redirect_url] || activation_complete_url,
      given_name: current_user.first_name || current_user.email.split("@").first,
      family_name: current_user.last_name || "User",
      email: current_user.email,
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id
      }
    }

    result = @gocardless_service.create_redirect_flow(redirect_params)

    if result[:success]
      # Store session token in session for verification
      session[:gocardless_session_token] = session_token

      render json: {
        success: true,
        redirect_url: result[:redirect_flow][:redirect_url],
        session_token: session_token
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/redirect_flow/:id/complete
  def complete_redirect_flow
    result = @gocardless_service.complete_redirect_flow(params[:id])

    if result[:success]
      # Get the mandate and customer from the completed redirect flow
      mandate_id = result[:redirect_flow][:links][:mandate]
      customer_id = result[:redirect_flow][:links][:customer]

      # Update organization billing
      update_organization_billing(customer_id, mandate_id)

      render json: {
        success: true,
        mandate_id: mandate_id,
        customer_id: customer_id
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/mandates
  def create_mandate
    mandate_params = {
      customer_id: params[:customer_id],
      scheme: params[:scheme] || "bacs",
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id
      }
    }

    result = @gocardless_service.create_mandate(mandate_params)

    if result[:success]
      render json: {
        success: true,
        mandate: result[:mandate]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/payments
  def create_payment
    payment_params = {
      amount: params[:amount], # Amount in pence
      currency: params[:currency] || "GBP",
      mandate_id: params[:mandate_id],
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id
      }
    }

    result = @gocardless_service.create_payment(payment_params)

    if result[:success]
      render json: {
        success: true,
        payment: result[:payment]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/subscriptions
  def create_subscription
    subscription_params = {
      amount: params[:amount], # Amount in pence
      currency: params[:currency] || "GBP",
      mandate_id: params[:mandate_id],
      interval_unit: params[:interval_unit] || "monthly",
      interval: params[:interval] || 1,
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id
      }
    }

    result = @gocardless_service.create_subscription(subscription_params)

    if result[:success]
      render json: {
        success: true,
        subscription: result[:subscription]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /gocardless/subscriptions/:id
  def subscription
    result = @gocardless_service.fetch_subscription(params[:id])

    if result[:success]
      render json: {
        success: true,
        subscription: result[:subscription]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # DELETE /gocardless/subscriptions/:id
  def cancel_subscription
    result = @gocardless_service.cancel_subscription(params[:id])

    if result[:success]
      render json: {
        success: true,
        subscription: result[:subscription]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /gocardless/customers/:id/payments
  def customer_payments
    result = @gocardless_service.fetch_customer_payments(params[:id])

    if result[:success]
      render json: {
        success: true,
        payments: result[:payments]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /gocardless/webhook
  def webhook
    payload = request.body.read
    signature = request.env["HTTP_WEBHOOK_SIGNATURE"]

    result = @gocardless_service.handle_webhook(payload, signature)

    if result[:success]
      handle_webhook_events(result[:events])
      render json: { received: true }
    else
      render json: { error: result[:error] }, status: :bad_request
    end
  end

  private

  def set_gocardless_service
    @gocardless_service = GoCardlessService.new(environment: Rails.env.production? ? "live" : "sandbox")
  end

  def update_organization_billing(customer_id, mandate_id)
    organization = current_user.organizations.first
    return unless organization

    billing = organization.organization_billing || organization.build_organization_billing
    billing.update!(
      billing_status: "active",
      provider: "gocardless",
      gocardless_customer_id: customer_id,
      gocardless_mandate_id: mandate_id
    )
  end

  def handle_webhook_events(events)
    events.each do |event|
      case event["resource_type"]
      when "payments"
        handle_payment_event(event)
      when "subscriptions"
        handle_subscription_event(event)
      when "mandates"
        handle_mandate_event(event)
      end
    end
  end

  def handle_payment_event(event)
    case event["action"]
    when "confirmed"
      Rails.logger.info "Payment confirmed: #{event["id"]}"
    when "failed"
      Rails.logger.info "Payment failed: #{event["id"]}"
    when "cancelled"
      Rails.logger.info "Payment cancelled: #{event["id"]}"
    end
  end

  def handle_subscription_event(event)
    case event["action"]
    when "created"
      Rails.logger.info "Subscription created: #{event["id"]}"
    when "cancelled"
      Rails.logger.info "Subscription cancelled: #{event["id"]}"
    when "finished"
      Rails.logger.info "Subscription finished: #{event["id"]}"
    end
  end

  def handle_mandate_event(event)
    case event["action"]
    when "created"
      Rails.logger.info "Mandate created: #{event["id"]}"
    when "cancelled"
      Rails.logger.info "Mandate cancelled: #{event["id"]}"
    when "failed"
      Rails.logger.info "Mandate failed: #{event["id"]}"
    end
  end
end
