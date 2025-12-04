class Admin::PatientPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "patients", "index")
  end

  def show?
    accessible?("admin", "patients", "show")
  end

  def create?
    accessible?("admin", "patients", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "patients", "update")
  end

  def fetch_from_ezclaim?
    accessible?("admin", "patients", "create")
  end

  def save_from_ezclaim?
    accessible?("admin", "patients", "create")
  end


  def edit?
    update?
  end

  def mark_deceased?
    accessible?("admin", "patients", "update")
  end

  def reactivate?
    accessible?("admin", "patients", "update")
  end

  def destroy?
    accessible?("admin", "patients", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
