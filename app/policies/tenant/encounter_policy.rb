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

  def submit_for_billing?
    accessible?("tenant", "encounters", "submit_for_billing")
  end

  def billing_data?
    submit_for_billing?
  end

  def procedure_codes_search?
    submit_for_billing?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
