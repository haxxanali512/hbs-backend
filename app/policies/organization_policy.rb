class OrganizationPolicy < ApplicationPolicy
  def index?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("index", "organization_management_module", "organizations")
  end

  def show?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "organizations")
  end

  def create?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("create", "organization_management_module", "organizations")
  end

  def update?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "organizations")
  end

  def destroy?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("destroy", "organization_management_module", "organizations")
  end

  def activate?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "activation")
  end

  def billing_setup?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "billing")
  end

  def compliance_setup?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "compliance")
  end

  def dashboard?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "organizations")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      elsif organization
        scope.where(id: organization.id)
      else
        scope.none
      end
    end
  end
end
