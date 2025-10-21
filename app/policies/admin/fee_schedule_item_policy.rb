class Admin::FeeScheduleItemPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "fee_schedule_items", "index")
  end

  def show?
    accessible?("admin", "fee_schedule_items", "show")
  end

  def create?
    accessible?("admin", "fee_schedule_items", "create")
  end

  def new?
    accessible?("admin", "fee_schedule_items", "create")
  end

  def update?
    accessible?("admin", "fee_schedule_items", "update")
  end

  def edit?
    accessible?("admin", "fee_schedule_items", "update")
  end

  def destroy?
    accessible?("admin", "fee_schedule_items", "destroy")
  end

  def activate?
    accessible?("admin", "fee_schedule_items", "update")
  end

  def deactivate?
    accessible?("admin", "fee_schedule_items", "update")
  end

  def lock?
    accessible?("admin", "fee_schedule_items", "update")
  end

  def unlock?
    accessible?("admin", "fee_schedule_items", "update")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
