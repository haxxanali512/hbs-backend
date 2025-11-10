class Tenant::ProviderNotePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "provider_notes", "index")
  end

  def show?
    accessible?("tenant", "provider_notes", "show")
  end

  def create?
    accessible?("tenant", "provider_notes", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "provider_notes", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "provider_notes", "destroy")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def current_provider
    # Get provider associated with current user
    return nil unless user
    Provider.find_by(user_id: user.id)
  end
end
