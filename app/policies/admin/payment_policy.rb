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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
