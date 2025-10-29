class Tenant::EncounterPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "encounters", "index")
  end

  def show?
    accessible?("tenant", "encounters", "show")
  end

  def create?
    accessible?("tenant", "encounters", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "encounters", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "encounters", "destroy")
  end

  def confirm_completed?
    accessible?("tenant", "encounters", "confirm_completed")
  end

  def cancel?
    accessible?("tenant", "encounters", "cancel")
  end

  def request_correction?
    accessible?("tenant", "encounters", "request_correction")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
