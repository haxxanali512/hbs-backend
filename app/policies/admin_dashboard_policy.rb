class AdminDashboardPolicy < ApplicationPolicy
  def index?
    return true if user.super_admin?
    return false unless current_org_member?
    accessible?("index", "users_management_module", "dashboard")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
