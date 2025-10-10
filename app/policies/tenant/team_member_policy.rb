class Tenant::TeamMemberPolicy < ApplicationPolicy
  def index?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("index", "tenant_management_module", "team_members")
  end

  def show?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("show", "tenant_management_module", "team_members")
  end

  def create?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("create", "tenant_management_module", "team_members")
  end

  def update?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("update", "tenant_management_module", "team_members")
  end

  def destroy?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("destroy", "tenant_management_module", "team_members")
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
