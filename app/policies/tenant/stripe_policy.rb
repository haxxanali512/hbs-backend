module Tenant
  class StripePolicy < ApplicationPolicy
    def setup_intent?
      accessible?("tenant", "stripe", "setup_intent")
    end
  end

  def confirm_card?
    accessible?("tenant", "stripe", "confirm_card")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
