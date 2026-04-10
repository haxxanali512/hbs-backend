class Tenant::OrganizationSettingPolicy < ApplicationPolicy
  def show?
    accessible?("tenant", "organization_settings", "show")
  end

  def update?
    accessible?("tenant", "organization_settings", "update")
  end

  def edit?
    update?
  end

  def update_billing_method?
    update?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
