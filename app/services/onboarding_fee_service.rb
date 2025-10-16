class OnboardingFeeService
  include ActiveModel::Model

  ONBOARDING_FEE_AMOUNT = 50000 # $500.00 in cents

  def self.charge_onboarding_fee!(organization)
    new(organization).charge!
  end

  def initialize(organization)
    @organization = organization
    @billing = organization.organization_billing
  end

  def charge!
    return { success: false, error: "Billing not configured" } unless @billing&.active?

    case @billing.provider
    when "stripe"
      charge_with_stripe
    when "gocardless"
      charge_with_gocardless
    when "manual"
      record_manual_onboarding_fee
    else
      { success: false, error: "Unsupported payment provider: #{@billing.provider}" }
    end
  end

  private

  def charge_with_stripe
    return { success: false, error: "Stripe not configured" } unless @billing.stripe_customer_id.present? && @billing.stripe_payment_method_id.present?

    Stripe.api_key = Rails.configuration.stripe[:secret_key]

    params = {
      amount: ONBOARDING_FEE_AMOUNT,
      currency: "usd",
      customer: @billing.stripe_customer_id,
      payment_method: @billing.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      description: "HBS Onboarding Fee - #{@organization.name}",
      metadata: {
        organization_id: @organization.id.to_s,
        fee_type: "onboarding",
        billing_period: "one_time"
      }
    }

    begin
      payment_intent = Stripe::PaymentIntent.create(params)

      # Update billing record with onboarding fee payment
      @billing.update!(
        last_payment_date: Time.current,
        next_payment_due: 1.month.from_now
      )

      # Log the transaction
      Rails.logger.info "Onboarding fee charged via Stripe: #{payment_intent.id} for organization #{@organization.id}"

      { success: true, payment_intent: payment_intent }
    rescue Stripe::CardError => e
      Rails.logger.error "Stripe onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def charge_with_gocardless
    return { success: false, error: "GoCardless not configured" } unless @billing.gocardless_customer_id.present? && @billing.gocardless_mandate_id.present?

    gocardless_service = GocardlessService.new

    # Convert cents to pence (GoCardless uses pence for GBP)
    amount_pence = ONBOARDING_FEE_AMOUNT

    params = {
      amount: amount_pence,
      currency: "GBP", # GoCardless primarily supports GBP
      mandate_id: @billing.gocardless_mandate_id,
      description: "HBS Onboarding Fee - #{@organization.name}",
      metadata: {
        organization_id: @organization.id.to_s,
        fee_type: "onboarding",
        billing_period: "one_time"
      }
    }

    begin
      result = gocardless_service.create_payment(params)

      if result[:success]
        # Update billing record with onboarding fee payment
        @billing.update!(
          last_payment_date: Time.current,
          next_payment_due: 1.month.from_now
        )

        # Log the transaction
        Rails.logger.info "Onboarding fee charged via GoCardless: #{result[:payment][:id]} for organization #{@organization.id}"

        { success: true, payment: result[:payment] }
      else
        Rails.logger.error "GoCardless onboarding fee error: #{result[:error]}"
        { success: false, error: result[:error] }
      end
    rescue => e
      Rails.logger.error "GoCardless onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def record_manual_onboarding_fee
    # For manual payments, just record the fee without charging
    @billing.update!(
      last_payment_date: Time.current,
      next_payment_due: 1.month.from_now
    )

    # Log the manual onboarding fee
    Rails.logger.info "Manual onboarding fee recorded for organization #{@organization.id} - requires admin approval"

    { success: true, message: "Manual onboarding fee recorded - requires admin approval" }
  end
end
