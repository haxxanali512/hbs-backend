class Admin::ProviderNotePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "provider_notes", "index")
  end

  def show?
    accessible?("admin", "provider_notes", "show")
  end

  def create?
    accessible?("admin", "provider_notes", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "provider_notes", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "provider_notes", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
