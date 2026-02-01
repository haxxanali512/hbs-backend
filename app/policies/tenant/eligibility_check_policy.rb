class Tenant::EligibilityCheckPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def new?
    true
  end
end
