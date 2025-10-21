class Tenant::FeeScheduleItemPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "fee_schedule_items", "index")
  end

  def show?
    accessible?("tenant", "fee_schedule_items", "show")
  end

  def create?
    accessible?("tenant", "fee_schedule_items", "create")
  end

  def new?
    accessible?("tenant", "fee_schedule_items", "create")
  end

  def update?
    accessible?("tenant", "fee_schedule_items", "update")
  end

  def edit?
    accessible?("tenant", "fee_schedule_items", "update")
  end

  def destroy?
    accessible?("tenant", "fee_schedule_items", "destroy")
  end

  def activate?
    accessible?("tenant", "fee_schedule_items", "update")
  end

  def deactivate?
    accessible?("tenant", "fee_schedule_items", "update")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
