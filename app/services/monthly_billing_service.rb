class MonthlyBillingService
  include ActiveModel::Model

  # Charge an organization for a given period using Stripe PaymentIntent (off-session)
  def self.charge!(organization_id, period:)
    organization = Organization.find(organization_id)
    billing = organization.organization_billing
    raise "Billing not configured" unless billing&.stripe? && billing.stripe_customer_id.present?

    # Compute totals (stubbed calculator for now)
    total_cents, line_items = ClaimsCalculator.calculate(organization, period)

    # Persist invoice records if/when models exist (placeholder)
    # invoice = Invoice.create!(organization: organization, period_start: period.begin, period_end: period.end, total_cents: total_cents)
    invoice = OpenStruct.new(id: "pending", total_cents: total_cents) # placeholder to carry metadata

    Stripe.api_key = Rails.configuration.stripe[:secret_key]

    params = {
      amount: total_cents,
      currency: "usd",
      customer: billing.stripe_customer_id,
      payment_method: billing.stripe_payment_method_id,
      off_session: true,
      confirm: true,
      metadata: {
        organization_id: organization.id,
        invoice_id: invoice.id,
        period: period.to_s
      }
    }

    begin
      pi = Stripe::PaymentIntent.create(params)
      # invoice.update!(payment_intent_id: pi.id, status: "paid") if invoice.respond_to?(:update!)
      billing.update!(last_payment_date: Time.current, next_payment_due: (period.end + 1.month))
      { success: true, payment_intent: pi }
    rescue Stripe::CardError => e
      # invoice.update!(status: "failed", failure_reason: e.message) if invoice.respond_to?(:update!)
      { success: false, error: e.message }
    rescue Stripe::StripeError => e
      { success: false, error: e.message }
    end
  end
end

# Temporary stub for claims calculator until claims tables are implemented
class ClaimsCalculator
  def self.calculate(organization, period)
    # TODO: Replace with real aggregation over claims tables when available
    total_cents = 0
    line_items = []
    [ total_cents, line_items ]
  end
end
