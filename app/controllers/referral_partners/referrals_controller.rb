class ReferralPartners::ReferralsController < ReferralPartners::BaseController
  def index
    @relationships = current_referral_partner.referral_relationships.includes(:referred_org).order(created_at: :desc)
  end

  def show
    @relationship = current_referral_partner.referral_relationships.includes(:referral_commissions).find(params[:id])
  end
end
