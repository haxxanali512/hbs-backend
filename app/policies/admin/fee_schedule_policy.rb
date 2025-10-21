class Admin::FeeSchedulePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "fee_schedules", "index")
  end

  def show?
    accessible?("admin", "fee_schedules", "show")
  end

  def create?
    accessible?("admin", "fee_schedules", "create")
  end

  def new?
    accessible?("admin", "fee_schedules", "create")
  end

  def update?
    accessible?("admin", "fee_schedules", "update")
  end

  def edit?
    accessible?("admin", "fee_schedules", "update")
  end

  def destroy?
    accessible?("admin", "fee_schedules", "destroy")
  end

  def lock?
    accessible?("admin", "fee_schedules", "update")
  end

  def unlock?
    accessible?("admin", "fee_schedules", "update")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
