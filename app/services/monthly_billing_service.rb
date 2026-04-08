class MonthlyBillingService
  include ActiveModel::Model

  DEDUCTIBLE_FEE_CENTS = 1000
  MODULE_SUBSCRIPTION_CATALOG = {
    "appointment" => { name: "Appointment Module", monthly_fee_cents: 9900 },
    "calendar" => { name: "Calendar Module", monthly_fee_cents: 9900 },
    "eligibility" => { name: "Eligibility Module", monthly_fee_cents: 7900 }
  }.freeze

  # Charge an organization for a given period using their configured payment provider.
  # This creates (or reuses) a monthly revenue-share invoice and attempts collection
  # against the organization's attached account when supported.
  def self.charge!(organization_id, period:)
    organization = Organization.find(organization_id)
    billing = organization.organization_billing
    raise "Billing not configured" unless billing&.active?

    invoice = create_or_find_invoice!(organization, period)
    return { success: true, invoice: invoice, skipped: true, message: "Already paid" } if invoice.paid?
    return { success: true, invoice: invoice, skipped: true, message: "No balance due" } if dollars_to_cents(invoice.amount_due) <= 0

    case billing.provider
    when "stripe"
      charge_with_stripe(billing, invoice, organization, period)
    when "gocardless"
      charge_with_gocardless(billing, invoice, organization, period)
    when "manual"
      billing.update!(next_payment_due: (period.end + 1.month))
      { success: true, invoice: invoice, message: "Manual payment provider configured - invoice generated and awaiting payment" }
    else
      { success: false, error: "Unsupported payment provider: #{billing.provider}" }
    end
  rescue => e
    Rails.logger.error("[MonthlyBillingService] charge failed org=#{organization_id} period=#{period}: #{e.class} #{e.message}")
    { success: false, error: e.message }
  end

  # Preview-only breakdown used by admin UI modal.
  # Returns raw calculation payload including line items in cents.
  def self.preview_breakdown(organization:, period:)
    ClaimsCalculator.calculate(organization, period)
  end

  private

  def self.charge_with_stripe(billing, invoice, organization, period)
    raise "Stripe not configured" unless billing.stripe_customer_id.present? && billing.stripe_payment_method_id.present?

    Stripe.api_key = Rails.configuration.stripe[:secret_key]
    amount_cents = dollars_to_cents(invoice.amount_due)

    params = {
      amount: amount_cents,
      currency: "usd",
      customer: billing.stripe_customer_id,
      payment_method: billing.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      description: "HBS Monthly Billing - #{organization.name} (#{period.begin.strftime('%b %Y')})",
      metadata: {
        organization_id: organization.id.to_s,
        invoice_id: invoice.id.to_s,
        period: period.to_s
      }
    }

    begin
      pi = Stripe::PaymentIntent.create(params)
      invoice.apply_payment!(
        amount_cents / 100.0,
        payment_method: :stripe,
        payment_provider_id: pi.id,
        payment_provider_response: pi.to_h,
        status: :succeeded,
        paid_at: Time.current
      )
      billing.update!(last_payment_date: Time.current, next_payment_due: (period.end + 1.month))
      { success: true, invoice: invoice.reload, payment_intent: pi }
    rescue Stripe::CardError => e
      { success: false, error: e.message }
    rescue Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end

  def self.charge_with_gocardless(billing, invoice, organization, period)
    raise "GoCardless not configured" unless billing.gocardless_customer_id.present? && billing.gocardless_mandate_id.present?

    gocardless_service = GocardlessService.new

    amount_in_minor_units = dollars_to_cents(invoice.amount_due)

    params = {
      amount: amount_in_minor_units,
      currency: "GBP", # GoCardless primarily supports GBP
      mandate_id: billing.gocardless_mandate_id,
      metadata: {
        organization_id: organization.id.to_s,
        invoice_id: invoice.id.to_s,
        period: period.to_s,
        description: "HBS Monthly Billing - #{organization.name} (#{period.begin.strftime('%b %Y')})"
      }
    }

    begin
      result = gocardless_service.create_payment(params)

      if result[:success]
        invoice.apply_payment!(
          amount_in_minor_units / 100.0,
          payment_method: :gocardless,
          payment_provider_id: result[:payment][:id],
          payment_provider_response: result[:payment],
          status: :succeeded,
          paid_at: Time.current
        )
        billing.update!(last_payment_date: Time.current, next_payment_due: (period.end + 1.month))
        { success: true, invoice: invoice.reload, payment: result[:payment] }
      else
        { success: false, error: result[:error] }
      end
    rescue => e
      { success: false, error: e.message }
    end
  end

  def self.create_or_find_invoice!(organization, period)
    service_month = period.begin.strftime("%Y-%m")
    existing = organization.invoices.find_by(invoice_type: :revenue_share_monthly, service_month: service_month)
    return existing if existing.present?

    calculation = ClaimsCalculator.calculate(organization, period)
    subtotal_cents = calculation[:line_items].sum { |item| item[:amount_cents] }

    Invoice.transaction do
      issue_date = Date.current
      invoice = organization.invoices.create!(
        invoice_type: :revenue_share_monthly,
        status: :issued,
        issue_date: issue_date,
        due_date: due_date_for(issue_date),
        service_period_start: period.begin.to_date,
        service_period_end: period.end.to_date,
        service_month: service_month,
        currency: "USD",
        subtotal: subtotal_cents / 100.0,
        total: subtotal_cents / 100.0,
        percent_of_revenue_snapshot: calculation[:collection_rate_percent],
        collected_revenue_amount: calculation[:collections_cents] / 100.0,
        deductible_applied_claims_count: calculation[:deductible_claims_count],
        deductible_fee_snapshot: DEDUCTIBLE_FEE_CENTS / 100.0
      )

      calculation[:line_items].each do |item|
        invoice.add_line_item(
          description: item[:description],
          quantity: item[:quantity],
          unit_price: item[:unit_price_cents] / 100.0,
          percent_applied: item[:percent_applied],
          amount: item[:amount_cents] / 100.0
        )
      end

      invoice
    end
  end

  def self.dollars_to_cents(amount_decimal)
    (BigDecimal(amount_decimal.to_s) * 100).round(0).to_i
  end

  def self.due_date_for(issue_date)
    return issue_date.change(day: 15) if issue_date.day <= 15

    (issue_date + 1.month).beginning_of_month.change(day: 15)
  end
end

class ClaimsCalculator
  def self.calculate(organization, period)
    collections_cents = collected_reimbursements_cents(organization, period)
    collection_rate_percent = organization.tier_percentage.to_f
    collection_fee_cents = (collections_cents * collection_rate_percent / 100.0).round
    deductible_claims_count = deductible_claims_for_period(organization, period)

    line_items = []
    line_items.concat(collection_line_items(collection_fee_cents, collection_rate_percent))
    line_items.concat(deductible_line_items(deductible_claims_count))
    line_items.concat(module_subscription_line_items(organization))

    {
      collections_cents: collections_cents,
      collection_rate_percent: collection_rate_percent,
      deductible_claims_count: deductible_claims_count,
      line_items: line_items
    }
  end

  def self.collected_reimbursements_cents(organization, period)
    total = PaymentApplication.joins(:payment)
                              .where(payments: { organization_id: organization.id })
                              .where(line_status: [ PaymentApplication.line_statuses[:paid], PaymentApplication.line_statuses[:adjusted] ])
                              .where("COALESCE(payments.payment_date, payments.created_at::date) BETWEEN ? AND ?", period.begin.to_date, period.end.to_date)
                              .sum(:amount_applied)
    (BigDecimal(total.to_s) * 100).round(0).to_i
  end

  def self.collection_line_items(collection_fee_cents, collection_rate_percent)
    return [] unless collection_fee_cents.positive?

    [ {
      description: "Reimbursements (#{collection_rate_percent.to_i}%)",
      quantity: 1,
      unit_price_cents: collection_fee_cents,
      percent_applied: collection_rate_percent,
      amount_cents: collection_fee_cents
    } ]
  end

  def self.deductible_claims_for_period(organization, period)
    organization.claims
                .where(status: :applied_to_deductible)
                .where(finalized_at: period.begin..period.end)
                .count
  end

  def self.deductible_line_items(deductible_claims_count)
    return [] if deductible_claims_count <= 0

    deductible_fee_cents = deductible_claims_count * MonthlyBillingService::DEDUCTIBLE_FEE_CENTS
    [ {
      description: "Deductible-applied claims (#{deductible_claims_count} x $10.00)",
      quantity: deductible_claims_count,
      unit_price_cents: MonthlyBillingService::DEDUCTIBLE_FEE_CENTS,
      percent_applied: nil,
      amount_cents: deductible_fee_cents
    } ]
  end

  # Modules are read from organization_settings.feature_entitlements JSONB.
  #
  # Expected shape (example):
  # {
  #   "enabled_modules": { "appointment": true, "calendar": true },
  #   "module_billing_rates_cents": { "appointment": 12900 }
  # }
  def self.module_subscription_line_items(organization)
    settings = organization.organization_setting
    entitlements = settings&.feature_entitlements || {}
    enabled_modules = read_enabled_modules(entitlements)
    custom_rates = read_custom_module_rates(entitlements)

    enabled_modules.filter_map do |module_key|
      catalog_entry = MonthlyBillingService::MODULE_SUBSCRIPTION_CATALOG[module_key]
      next if catalog_entry.blank?

      monthly_fee_cents = custom_rates[module_key].presence || catalog_entry[:monthly_fee_cents]
      next unless monthly_fee_cents.to_i.positive?

      {
        description: "#{catalog_entry[:name]} subscription",
        quantity: 1,
        unit_price_cents: monthly_fee_cents.to_i,
        percent_applied: nil,
        amount_cents: monthly_fee_cents.to_i
      }
    end
  end

  def self.read_enabled_modules(entitlements)
    raw_enabled = entitlements["enabled_modules"] || entitlements[:enabled_modules] || {}

    case raw_enabled
    when Hash
      raw_enabled.select { |_k, v| ActiveModel::Type::Boolean.new.cast(v) }.keys.map(&:to_s)
    when Array
      raw_enabled.map(&:to_s)
    else
      []
    end
  end

  def self.read_custom_module_rates(entitlements)
    raw_rates = entitlements["module_billing_rates_cents"] || entitlements[:module_billing_rates_cents] || {}
    return {} unless raw_rates.is_a?(Hash)

    raw_rates.each_with_object({}) do |(key, value), acc|
      acc[key.to_s] = value.to_i
    end
  end
end
