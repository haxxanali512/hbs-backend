class Tenant::ProviderPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "providers", "index")
  end

  def show?
    accessible?("tenant", "providers", "show")
  end

  def new?
    accessible?("tenant", "providers", "create")
  end

  def edit?
    accessible?("tenant", "providers", "update")
  end

  def create?
    accessible?("tenant", "providers", "create")
  end

  def update?
    accessible?("tenant", "providers", "update")
  end

  def destroy?
    accessible?("tenant", "providers", "destroy")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
