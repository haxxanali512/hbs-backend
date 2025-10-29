class Tenant::PatientPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "patients", "index")
  end

  def show?
    accessible?("tenant", "patients", "show")
  end

  def create?
    accessible?("tenant", "patients", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "patients", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "patients", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end

