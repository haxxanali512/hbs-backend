class StripeController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stripe_service

  # GET /stripe/products
  def products
    result = @stripe_service.fetch_products(limit: params[:limit]&.to_i || 100)

    if result[:success]
      render json: {
        success: true,
        products: result[:products],
        has_more: result[:has_more]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /stripe/products/:id/prices
  def product_prices
    result = @stripe_service.fetch_product_prices(params[:id])

    if result[:success]
      render json: {
        success: true,
        prices: result[:prices]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /stripe/checkout_session
  def create_checkout_session
    # Get the selected product and price
    product_id = params[:product_id]
    price_id = params[:price_id]
    mode = params[:mode] || "payment" # 'payment' or 'subscription'

    # Fetch product details
    product_result = @stripe_service.fetch_product(product_id)
    return render_error(product_result[:error]) unless product_result[:success]

    # Prepare line items for checkout session
    line_items = [ {
      price: price_id,
      quantity: params[:quantity]&.to_i || 1
    } ]

    # Prepare checkout session parameters
    checkout_params = {
      line_items: line_items,
      mode: mode,
      success_url: params[:success_url] || activation_complete_url,
      cancel_url: params[:cancel_url] || activation_billing_setup_url,
      customer_email: current_user.email,
      metadata: {
        user_id: current_user.id,
        organization_id: current_user.organizations.first&.id,
        product_id: product_id
      }
    }

    # Add subscription-specific parameters
    if mode == "subscription"
      checkout_params[:subscription_data] = {
        metadata: {
          user_id: current_user.id,
          organization_id: current_user.organizations.first&.id
        }
      }
    end

    # Create checkout session
    result = @stripe_service.create_checkout_session(checkout_params)

    if result[:success]
      render json: {
        success: true,
        session_id: result[:session_id],
        session_url: result[:session_url]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /stripe/checkout_session/:id
  def checkout_session
    result = @stripe_service.fetch_checkout_session(params[:id])

    if result[:success]
      render json: {
        success: true,
        session: result[:session]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # POST /stripe/webhook
  def webhook
    payload = request.body.read
    signature = request.env["HTTP_STRIPE_SIGNATURE"]

    result = @stripe_service.handle_webhook(payload, signature)

    if result[:success]
      handle_webhook_event(result[:event])
      render json: { received: true }
    else
      render json: { error: result[:error] }, status: :bad_request
    end
  end

  private

  def set_stripe_service
    @stripe_service = StripeService.new(environment: Rails.env.production? ? "live" : "test")
  end

  def render_error(message)
    render json: {
      success: false,
      error: message
    }, status: :unprocessable_entity
  end

  def handle_webhook_event(event)
    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "customer.subscription.created"
      handle_subscription_created(event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    when "invoice.payment_succeeded"
      handle_payment_succeeded(event.data.object)
    when "invoice.payment_failed"
      handle_payment_failed(event.data.object)
    end
  end

  def handle_checkout_completed(session)
    # Update organization billing status
    organization_id = session.metadata["organization_id"]
    return unless organization_id

    organization = Organization.find_by(id: organization_id)
    return unless organization

    # Create or update billing record
    billing = organization.organization_billing || organization.build_organization_billing
    billing.update!(
      billing_status: "active",
      provider: "stripe",
      stripe_session_id: session.id,
      stripe_customer_id: session.customer
    )

    # If it's a subscription, store the subscription ID
    if session.mode == "subscription" && session.subscription
      billing.update!(stripe_subscription_id: session.subscription)
    end
  end

  def handle_subscription_created(subscription)
    # Handle subscription creation
    Rails.logger.info "Subscription created: #{subscription.id}"
  end

  def handle_subscription_updated(subscription)
    # Handle subscription updates
    Rails.logger.info "Subscription updated: #{subscription.id}"
  end

  def handle_subscription_deleted(subscription)
    # Handle subscription cancellation
    billing = OrganizationBilling.find_by(stripe_subscription_id: subscription.id)
    billing&.update!(billing_status: "cancelled")
  end

  def handle_payment_succeeded(invoice)
    # Handle successful payment
    Rails.logger.info "Payment succeeded for invoice: #{invoice.id}"
  end

  def handle_payment_failed(invoice)
    # Handle failed payment
    Rails.logger.info "Payment failed for invoice: #{invoice.id}"
  end
end
