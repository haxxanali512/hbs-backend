class ReferralPartners::ProfilePolicy < ApplicationPolicy
  def show?
    accessible?("referral_partner", "profiles", "show")
  end

  def edit?
    accessible?("referral_partner", "profiles", "edit")
  end

  def update?
    accessible?("referral_partner", "profiles", "update")
  end
end
