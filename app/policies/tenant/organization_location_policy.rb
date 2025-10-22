class Tenant::OrganizationLocationPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "organization_locations", "index")
  end

  def show?
    accessible?("tenant", "organization_locations", "show")
  end

  def create?
    accessible?("tenant", "organization_locations", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "organization_locations", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "organization_locations", "destroy")
  end

  def activate?
    accessible?("tenant", "organization_locations", "activate")
  end

  def inactivate?
    accessible?("tenant", "organization_locations", "inactivate")
  end

  def reactivate?
    accessible?("tenant", "organization_locations", "reactivate")
  end

  # Tenant users cannot retire locations (HBS_Admin/Super only)
  def retire?
    false
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
