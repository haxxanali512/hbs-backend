class Admin::ResourcePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "resources", "index")
  end

  def show?
    accessible?("admin", "resources", "show")
  end

  def create?
    accessible?("admin", "resources", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "resources", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "resources", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end

