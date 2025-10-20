class Tenant::StripeController < Tenant::BaseController
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

  # POST /stripe/setup_intent
  def setup_intent
    organization = current_user.organizations.first
    return render_error("Organization not found") unless organization

    billing = organization.organization_billing || organization.build_organization_billing

    # Ensure Stripe customer exists (reuse existing if present)
    customer_id = billing.stripe_customer_id
    unless customer_id.present?
      customer_result = @stripe_service.find_or_create_customer(
        email: current_user.email,
        name: [ current_user.first_name, current_user.last_name ].compact.join(" "),
        metadata: { user_id: current_user.id, organization_id: organization.id }
      )
      return render_error(customer_result[:error]) unless customer_result[:success]
      customer_id = customer_result[:customer].id
      billing.update!(stripe_customer_id: customer_id)
    end

    si_result = @stripe_service.create_setup_intent(customer_id)
    if si_result[:success]
      render json: { success: true, client_secret: si_result[:client_secret] }
    else
      render_error(si_result[:error])
    end
  end

  # POST /stripe/confirm_card
  # params: payment_method_id
  def confirm_card
    organization = current_user.organizations.first
    return render_error("Organization not found") unless organization

    billing = organization.organization_billing || organization.build_organization_billing
    return render_error("payment_method_id required") unless params[:payment_method_id].present?

    customer_id = billing.stripe_customer_id
    unless customer_id.present?
      cust_result = @stripe_service.find_or_create_customer(
        email: current_user.email,
        name: [ current_user.first_name, current_user.last_name ].compact.join(" "),
        metadata: { user_id: current_user.id, organization_id: organization.id }
      )
      return render_error(cust_result[:error]) unless cust_result[:success]
      customer_id = cust_result[:customer].id
    end

    # Set as default payment method
    set_result = @stripe_service.set_default_payment_method(customer_id, params[:payment_method_id])
    return render_error(set_result[:error]) unless set_result[:success]

    # Retrieve PM for brand/last4
    pm_result = @stripe_service.retrieve_payment_method(params[:payment_method_id])
    return render_error(pm_result[:error]) unless pm_result[:success]
    card = pm_result[:payment_method].card

    # Persist on billing and advance activation step
    billing.update!(
      provider: :stripe,
      billing_status: :active,
      stripe_customer_id: customer_id,
      stripe_payment_method_id: params[:payment_method_id],
      method_last4: card&.last4,
      card_brand: card&.brand,
      card_exp_month: card&.exp_month,
      card_exp_year: card&.exp_year
    )

    # Move organization to next step if currently at billing
    if organization.pending?
      organization.setup_billing!
    end

    # Charge onboarding fee
    onboarding_result = OnboardingFeeService.charge_onboarding_fee!(organization)

    if onboarding_result[:success]
      Rails.logger.info "Onboarding fee charged successfully for organization #{organization.id}"
    else
      Rails.logger.error "Failed to charge onboarding fee for organization #{organization.id}: #{onboarding_result[:error]}"
      # Don't fail the Stripe setup if onboarding fee fails - just log it
    end

    render json: { success: true }
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
    when "setup_intent.succeeded"
      handle_setup_intent_succeeded(event.data.object)
    when "payment_method.attached"
      handle_payment_method_attached(event.data.object)
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
    when "payment_intent.succeeded"
      handle_payment_intent_succeeded(event.data.object)
    when "payment_intent.payment_failed"
      handle_payment_intent_failed(event.data.object)
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

  def handle_setup_intent_succeeded(setup_intent)
    # Optionally reconcile if needed
    Rails.logger.info "SetupIntent succeeded: #{setup_intent.id}"
  end

  def handle_payment_method_attached(payment_method)
    # Optionally update billing metadata
    Rails.logger.info "PaymentMethod attached: #{payment_method.id}"
  end

  def handle_payment_intent_succeeded(payment_intent)
    Rails.logger.info "PaymentIntent succeeded: #{payment_intent.id}"
  end

  def handle_payment_intent_failed(payment_intent)
    Rails.logger.info "PaymentIntent failed: #{payment_intent.id}"
  end
end
