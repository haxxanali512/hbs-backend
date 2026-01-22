class Admin::PaymentPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "payments", "index")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
