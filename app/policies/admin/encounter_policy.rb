class Admin::EncounterPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "encounters", "index")
  end

  def show?
    accessible?("admin", "encounters", "show")
  end

  def create?
    accessible?("admin", "encounters", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "encounters", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "encounters", "destroy")
  end

  def cancel?
    accessible?("admin", "encounters", "cancel")
  end

  def override_validation?
    accessible?("admin", "encounters", "override_validation")
  end

  def request_correction?
    accessible?("admin", "encounters", "request_correction")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
