class ReferralPartners::DashboardController < ReferralPartners::BaseController
  def index
    @referral_partner = current_referral_partner
    @relationships = @referral_partner.referral_relationships.order(created_at: :desc)
    @commissions = @referral_partner.referral_commissions.order(month: :desc)
    @current_month_earnings = @commissions.where(month: Date.current.beginning_of_month).sum(:commission_amount)
  end
end
