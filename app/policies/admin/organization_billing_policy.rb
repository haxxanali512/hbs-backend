module Admin
  class OrganizationBillingPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "organizations", "index")
  end

  def show?
    accessible?("admin", "organizations", "show")
  end

  def approve?
    accessible?("admin", "organizations", "approve")
  end

  def reject?
    accessible?("admin", "organizations", "reject")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
  end
end
