class Tenant::FeeSchedulePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "fee_schedules", "index")
  end

  def show?
    accessible?("tenant", "fee_schedules", "show")
  end

  def create?
    accessible?("tenant", "fee_schedules", "create")
  end

  def new?
    accessible?("tenant", "fee_schedules", "create")
  end

  def update?
    accessible?("tenant", "fee_schedules", "update")
  end

  def edit?
    accessible?("tenant", "fee_schedules", "update")
  end

  def destroy?
    accessible?("tenant", "fee_schedules", "destroy")
  end

  def lock?
    accessible?("tenant", "fee_schedules", "update")
  end

  def unlock?
    accessible?("tenant", "fee_schedules", "update")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
