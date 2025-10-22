class Admin::OrganizationLocationPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "organization_locations", "index")
  end

  def show?
    accessible?("admin", "organization_locations", "show")
  end

  def update?
    accessible?("admin", "organization_locations", "update")
  end

  def edit?
    update?
  end

  def activate?
    accessible?("admin", "organization_locations", "activate")
  end

  def inactivate?
    accessible?("admin", "organization_locations", "inactivate")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
