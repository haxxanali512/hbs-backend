class Admin::PaymentPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "payments", "index")
  end

  def new?
    accessible?("admin", "payments", "create")
  end

  def create?
    new?
  end

  def edit?
    accessible?("admin", "payments", "update")
  end

  def update?
    edit?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
