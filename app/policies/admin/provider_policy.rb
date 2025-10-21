class Admin::ProviderPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "providers", "index")
  end

  def show?
    accessible?("admin", "providers", "show")
  end

  def new?
    accessible?("admin", "providers", "create")
  end

  def create?
    accessible?("admin", "providers", "create")
  end

  def edit?
    accessible?("admin", "providers", "update")
  end

  def update?
    accessible?("admin", "providers", "update")
  end

  def destroy?
    accessible?("admin", "providers", "destroy")
  end

  def approve?
    accessible?("admin", "providers", "update")
  end

  def reject?
    accessible?("admin", "providers", "update")
  end

  def suspend?
    accessible?("admin", "providers", "update")
  end

  def reactivate?
    accessible?("admin", "providers", "update")
  end

  def resubmit?
    accessible?("admin", "providers", "update")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
