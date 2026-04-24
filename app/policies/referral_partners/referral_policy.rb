module ReferralPartners
  class ReferralPolicy < ApplicationPolicy
    def index?
      accessible?("referral_partner", "referrals", "index")
    end

    def show?
      accessible?("referral_partner", "referrals", "show")
    end
  end
end
