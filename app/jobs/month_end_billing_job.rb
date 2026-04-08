class MonthEndBillingJob < ApplicationJob
  queue_as :default

  def perform
    period_end_anchor = Time.current.beginning_of_month - 1.day
    period = period_end_anchor.beginning_of_month..period_end_anchor.end_of_month

    Organization.includes(:organization_billing).find_each do |org|
      billing = org.organization_billing
      next unless billing&.active?
      next unless billing.stripe? || billing.gocardless? || billing.manual?

      OrganizationMonthlyBillingJob.perform_later(
        org.id,
        period_start: period.begin.to_date,
        period_end: period.end.to_date
      )
    end
  end
end
