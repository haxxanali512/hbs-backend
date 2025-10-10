class Tenant::PatientPolicy < ApplicationPolicy
  def index?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("index", "medical_billing_module", "patients")
  end

  def show?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("show", "medical_billing_module", "patients")
  end

  def create?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("create", "medical_billing_module", "patients")
  end

  def update?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "medical_billing_module", "patients")
  end

  def destroy?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("destroy", "medical_billing_module", "patients")
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
