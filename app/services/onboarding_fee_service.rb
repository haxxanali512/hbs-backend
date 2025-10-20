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

    begin
      # Create invoice first
      invoice = create_onboarding_invoice

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
          invoice_id: invoice.id,
          fee_type: "onboarding",
          billing_period: "one_time"
        }
      }

      payment_intent = Stripe::PaymentIntent.create(params)
      # Record payment on invoice
      invoice.apply_payment!(
        ONBOARDING_FEE_AMOUNT / 100.0,
        payment_method: :stripe,
        payment_provider_id: payment_intent.id,
        payment_provider_response: payment_intent.to_h,
        status: :succeeded,
        paid_at: Time.current
      )

      # Update billing record with onboarding fee payment
      @billing.update!(
        last_payment_date: Time.current,
        next_payment_due: 1.month.from_now
      )

      # Log the transaction
      Rails.logger.info "Onboarding fee charged via Stripe: #{payment_intent.id} for organization #{@organization.id}, invoice #{invoice.invoice_number}"

      { success: true, payment_intent: payment_intent, invoice: invoice }
    rescue Stripe::CardError => e
      Rails.logger.error "Stripe onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    rescue => e
      Rails.logger.error "Onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def charge_with_gocardless
    return { success: false, error: "GoCardless not configured" } unless @billing.gocardless_customer_id.present? && @billing.gocardless_mandate_id.present?

    begin
      # Create invoice first
      invoice = create_onboarding_invoice

      gocardless_service = GocardlessService.new

      amount_pence = ONBOARDING_FEE_AMOUNT

      # Check the mandate to determine the correct currency
      mandate_result = gocardless_service.fetch_mandate(@billing.gocardless_mandate_id)

      if mandate_result[:success]
        mandate = mandate_result[:mandate]
        # Determine currency based on mandate scheme
        currency = case mandate[:scheme]
        when "ach"
          "USD"
        when "bacs", "sepa_core", "sepa_b2b"
          "GBP"
        else
          "GBP" # Default fallback
        end

        Rails.logger.info "Using currency #{currency} for mandate scheme #{mandate[:scheme]}"
      else
        Rails.logger.warn "Could not fetch mandate details, defaulting to GBP"
        currency = "GBP"
      end

      params = {
        amount: amount_pence,
        currency: currency,
        mandate_id: @billing.gocardless_mandate_id,
        metadata: {
          organization_id: @organization.id.to_s,
          invoice_id: invoice.id,
          fee_type: "onboarding",
          billing_period: "one_time",
          description: "HBS Onboarding Fee - #{@organization.name}"
        }
      }

      result = gocardless_service.create_payment(params)

      if result[:success]
        # Record payment on invoice
        invoice.apply_payment!(
          ONBOARDING_FEE_AMOUNT / 100.0,
          payment_method: :gocardless,
          payment_provider_id: result[:payment][:id],
          payment_provider_response: result[:payment],
          status: :succeeded,
          paid_at: Time.current
        )

        # Update billing record with onboarding fee payment
        @billing.update!(
          last_payment_date: Time.current,
          next_payment_due: 1.month.from_now
        )

        # Log the transaction
        Rails.logger.info "Onboarding fee charged via GoCardless: #{result[:payment][:id]} for organization #{@organization.id}, invoice #{invoice.invoice_number}"

        { success: true, payment: result[:payment], invoice: invoice }
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
    begin
      # Create invoice for manual payment
      invoice = create_onboarding_invoice

      # For manual payments, just record the fee without charging
      @billing.update!(
        last_payment_date: Time.current,
        next_payment_due: 1.month.from_now
      )

      # Log the manual onboarding fee
      Rails.logger.info "Manual onboarding fee invoice created for organization #{@organization.id}, invoice #{invoice.invoice_number} - requires admin approval"

      { success: true, message: "Manual onboarding fee recorded - requires admin approval", invoice: invoice }
    rescue => e
      Rails.logger.error "Manual onboarding fee error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def create_onboarding_invoice
    # Check if onboarding invoice already exists
    existing_invoice = @organization.invoices.where(invoice_type: :onboarding_fee).first
    return existing_invoice if existing_invoice

    # Create new invoice
    invoice = Invoice.create!(
      organization: @organization,
      invoice_type: :onboarding_fee,
      status: :issued,
      issue_date: Date.current,
      due_date: Date.current,
      currency: "USD",
      subtotal: ONBOARDING_FEE_AMOUNT / 100.0,
      total: ONBOARDING_FEE_AMOUNT / 100.0
    )

    # Add line item
    invoice.add_line_item(
      description: "HBS Onboarding Fee",
      quantity: 1,
      unit_price: ONBOARDING_FEE_AMOUNT / 100.0,
      amount: ONBOARDING_FEE_AMOUNT / 100.0
    )

    invoice
  end
end
