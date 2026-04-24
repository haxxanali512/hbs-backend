module ReferralPartners
  class DashboardController < BaseController
    def index
      @relationships = current_referral_partner.referral_relationships.order(created_at: :desc)
      @commissions = current_referral_partner.referral_commissions.order(month: :desc)
      @current_month_earnings = @commissions.where(month: Date.current.beginning_of_month).sum(:commission_amount)
    end
  end
end
