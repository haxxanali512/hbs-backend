class Admin::AppointmentPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "appointments", "index")
  end

  def show?
    accessible?("admin", "appointments", "show")
  end

  def create?
    accessible?("admin", "appointments", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "appointments", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "appointments", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
