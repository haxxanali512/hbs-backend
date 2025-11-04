class Admin::DenialItemPolicy < ApplicationPolicy
  def create?
    accessible?("admin", "denial_items", "create")
  end

  def update?
    accessible?("admin", "denial_items", "update")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
