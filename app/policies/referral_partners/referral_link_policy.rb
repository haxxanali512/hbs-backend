module ReferralPartners
  class ReferralLinkPolicy < ApplicationPolicy
    def show?
      accessible?("referral_partner", "referral_links", "show")
    end
  end
end
