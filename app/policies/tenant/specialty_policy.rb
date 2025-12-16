class Tenant::SpecialtyPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "specialties", "index")
  end

  def new?
    create?
  end

  def create?
    accessible?("tenant", "specialties", "create")
  end

  def edit?
    update?
  end

  def update?
    accessible?("tenant", "specialties", "update")
  end

  def destroy?
    accessible?("tenant", "specialties", "destroy")
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
