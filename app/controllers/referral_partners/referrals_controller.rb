module ReferralPartners
  class ReferralsController < BaseController
    def index
      @relationships = current_referral_partner.referral_relationships.order(created_at: :desc)
    end

    def show
      @relationship = current_referral_partner.referral_relationships.find(params[:id])
      @commissions = @relationship.referral_commissions.order(month: :desc)
    end
  end
end
