class OrganizationMonthlyBillingJob < ApplicationJob
  queue_as :default

  def perform(organization_id, period_start: nil, period_end: nil)
    period = resolved_period(period_start, period_end)
    result = MonthlyBillingService.charge!(organization_id, period: period)

    unless result[:success]
      Rails.logger.error("[OrganizationMonthlyBillingJob] org=#{organization_id} failed: #{result[:error]}")
    end
  rescue => e
    Rails.logger.error("[OrganizationMonthlyBillingJob] org=#{organization_id} exception: #{e.class} #{e.message}")
    raise
  end

  private

  def resolved_period(period_start, period_end)
    return period_start.to_date.beginning_of_day..period_end.to_date.end_of_day if period_start.present? && period_end.present?

    previous_month = Time.current.beginning_of_month - 1.day
    previous_month.beginning_of_month..previous_month.end_of_month
  end
end
