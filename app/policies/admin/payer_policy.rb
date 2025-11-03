class Admin::PayerPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "payers", "index")
  end

  def new?
    create?
  end

  def show?
    accessible?("admin", "payers", "show")
  end

  def edit?
    update?
  end

  def create?
    accessible?("admin", "payers", "create")
  end

  def update?
    accessible?("admin", "payers", "update")
  end

  def destroy?
    accessible?("admin", "payers", "destroy")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
