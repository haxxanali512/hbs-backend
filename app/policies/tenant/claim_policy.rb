class Tenant::ClaimPolicy < ApplicationPolicy
  def index?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("index", "medical_billing_module", "claims")
  end

  def show?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("show", "medical_billing_module", "claims")
  end

  def create?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("create", "medical_billing_module", "claims")
  end

  def update?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "medical_billing_module", "claims")
  end

  def destroy?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("destroy", "medical_billing_module", "claims")
  end

  def submit?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("submit", "medical_billing_module", "claims")
  end

  def appeal?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("appeal", "medical_billing_module", "claims")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif organization
        scope.where(organization: organization)
      else
        scope.none
      end
    end
  end
end
