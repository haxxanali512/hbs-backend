class ReferralPartnerMonthlyCommissionJob < ApplicationJob
  queue_as :default

  def perform(month = Date.current.prev_month.beginning_of_month)
    ReferralPartners::CommissionGenerationService.call(month:)
  end
end
