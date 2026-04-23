class Admin::ReferralRelationshipPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "referral_relationships", "index")
  end

  def show?
    accessible?("admin", "referral_relationships", "show")
  end

  def update?
    accessible?("admin", "referral_relationships", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "referral_relationships", "destroy")
  end

  def mark_ineligible?
    accessible?("admin", "referral_relationships", "mark_ineligible")
  end

  def export?
    accessible?("admin", "referral_relationships", "export")
  end
end
