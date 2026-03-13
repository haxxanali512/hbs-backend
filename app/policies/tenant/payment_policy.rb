class Tenant::PaymentPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "payments", "index")
  end

  def export?
    accessible?("tenant", "payments", "export")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
