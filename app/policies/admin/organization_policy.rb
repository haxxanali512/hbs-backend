module Admin
  class OrganizationPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "organizations", "index")
  end

  def new?
    accessible?("admin", "organizations", "create")
  end

  def edit?
    accessible?("admin", "organizations", "update")
  end

  def show?
    accessible?("admin", "organizations", "show")
  end

  def create?
    accessible?("admin", "organizations", "create")
  end

  def update?
    accessible?("admin", "organizations", "update")
  end

  def destroy?
    accessible?("admin", "organizations", "destroy")
  end

  def activate_tenant?
    accessible?("admin", "organizations", "activate_tenant")
  end

  def suspend_tenant?
    accessible?("admin", "organizations", "suspend_tenant")
  end

  def toggle_checklist_step?
    accessible?("admin", "organizations", "create")
  end

  def toggle_plan_step?
    accessible?("admin", "organizations", "update")
  end

  def users_search?
    index?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
  end
end
