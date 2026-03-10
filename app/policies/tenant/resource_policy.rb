class Tenant::ResourcePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "resources", "index")
  end

  def show?
    accessible?("tenant", "resources", "show")
  end

  class Scope < Scope
    def resolve
      scope.published
    end
  end
end

