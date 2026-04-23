class ReferralPartners::ReferralLinkPolicy < ApplicationPolicy
  def index?
    accessible?("referral_partner", "referral_links", "index")
  end
end
