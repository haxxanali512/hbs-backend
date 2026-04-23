class ReferralPartners::DashboardPolicy < ApplicationPolicy
  def index?
    accessible?("referral_partner", "dashboard", "index")
  end
end
