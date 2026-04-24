module ReferralPartners
  class DashboardPolicy < ApplicationPolicy
    def index?
      accessible?("referral_partner", "dashboard", "index")
    end
  end
end
