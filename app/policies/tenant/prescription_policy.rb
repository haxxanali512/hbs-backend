class Tenant::PrescriptionPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "prescriptions", "index")
  end

  def show?
    accessible?("tenant", "prescriptions", "show")
  end

  def create?
    accessible?("tenant", "prescriptions", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "prescriptions", "update")
  end

  def edit?
    update?
  end

  def procedure_codes_for_specialty?
    accessible?("tenant", "specialties", "index")
  end

  def destroy?
    accessible?("tenant", "prescriptions", "destroy")
  end

  def archive?
    accessible?("tenant", "prescriptions", "archive")
  end

  def unarchive?
    accessible?("tenant", "prescriptions", "unarchive")
  end

  def specialties_for_provider?
    create?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
