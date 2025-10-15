class MonthEndBillingJob < ApplicationJob
  queue_as :default

  def perform
    period = (Time.current.beginning_of_month - 1.day).beginning_of_month..(Time.current.beginning_of_month - 1.day).end_of_month
    Organization.includes(:organization_billing).find_each do |org|
      next unless org.organization_billing&.stripe? && org.organization_billing&.active?
      MonthlyBillingService.charge!(org.id, period: period)
    end
  end
end
