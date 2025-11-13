class Tenant::ProviderNotePolicy < ApplicationPolicy
  def index?
    # When record is a User (from has_access?), just check permission
    return accessible?("tenant", "provider_notes", "index") if record.is_a?(User)
    accessible?("tenant", "provider_notes", "index")
  end

  def show?
    # When record is a User (from has_access?), just check permission
    return accessible?("tenant", "provider_notes", "show") if record.is_a?(User)
    accessible?("tenant", "provider_notes", "show")
  end

  def create?
    # When record is a User (from has_access?), just check permission
    return accessible?("tenant", "provider_notes", "create") if record.is_a?(User)

    # When record is a ProviderNote, check encounter and provider
    return false if record.encounter.cascaded?
    user&.provider.present? && record.encounter.provider == user.provider && accessible?("tenant", "provider_notes", "create")
  end

  def new?
    create?
  end

  def update?
    # When record is a User (from has_access?), just check permission
    return accessible?("tenant", "provider_notes", "update") if record.is_a?(User)

    # When record is a ProviderNote, check encounter and provider
    return false if record.encounter.cascaded?
    user&.provider.present? && record.provider == user.provider && accessible?("tenant", "provider_notes", "update")
  end

  def edit?
    update?
  end

  def destroy?
    # When record is a User (from has_access?), just check permission
    return accessible?("tenant", "provider_notes", "destroy") if record.is_a?(User)

    # When record is a ProviderNote, check encounter and provider
    return false if record.encounter.cascaded?
    user&.provider.present? && record.provider == user.provider && accessible?("tenant", "provider_notes", "destroy")
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
