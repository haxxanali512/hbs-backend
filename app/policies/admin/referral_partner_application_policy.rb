class Admin::ReferralPartnerApplicationPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "referral_partner_applications", "index")
  end

  def show?
    accessible?("admin", "referral_partner_applications", "show")
  end

  def update?
    accessible?("admin", "referral_partner_applications", "update")
  end

  def approve?
    accessible?("admin", "referral_partner_applications", "approve")
  end

  def deny?
    accessible?("admin", "referral_partner_applications", "deny")
  end
end
