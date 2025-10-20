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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
  end
end
