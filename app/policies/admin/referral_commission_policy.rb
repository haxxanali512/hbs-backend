class Admin::ReferralCommissionPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "referral_commissions", "index")
  end

  def show?
    accessible?("admin", "referral_commissions", "show")
  end

  def update?
    accessible?("admin", "referral_commissions", "update")
  end

  def approve?
    accessible?("admin", "referral_commissions", "approve")
  end

  def mark_paid?
    accessible?("admin", "referral_commissions", "mark_paid")
  end

  def export?
    accessible?("admin", "referral_commissions", "export")
  end
end
