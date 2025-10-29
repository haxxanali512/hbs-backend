class Tenant::AppointmentPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "appointments", "index")
  end

  def show?
    accessible?("tenant", "appointments", "show")
  end

  def create?
    accessible?("tenant", "appointments", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "appointments", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "appointments", "destroy")
  end

  def cancel?
    accessible?("tenant", "appointments", "cancel")
  end

  def complete?
    accessible?("tenant", "appointments", "complete")
  end

  def mark_no_show?
    accessible?("tenant", "appointments", "mark_no_show")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
