class Admin::ReferralPartnerPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "referral_partners", "index")
  end

  def show?
    accessible?("admin", "referral_partners", "show")
  end

  def create?
    accessible?("admin", "referral_partners", "create")
  end

  def new?
    create?
  end

  def search_users?
    accessible?("admin", "users", "index")
  end

  def update?
    accessible?("admin", "referral_partners", "update")
  end

  def edit?
    update?
  end

  def suspend?
    accessible?("admin", "referral_partners", "suspend")
  end
end
