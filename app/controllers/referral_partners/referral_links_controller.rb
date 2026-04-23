class ReferralPartners::ReferralLinksController < ReferralPartners::BaseController
  def index
    @referral_partner = current_referral_partner
  end
end
