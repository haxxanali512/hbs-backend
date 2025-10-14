class TenantDashboardPolicy < ApplicationPolicy
  def index?
    # Allow access if user is a super admin or a member of the current organization
    user&.super_admin? || user&.member_of?(record[:organization])
  end

  def show?
    index?
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    false
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
