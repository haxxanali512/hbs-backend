class Tenant::SpecialtyPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "specialties", "index")
  end

  def show?
    accessible?("tenant", "specialties", "show")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
