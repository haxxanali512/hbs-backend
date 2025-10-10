class Tenant::BaseController < ApplicationController
  before_action :ensure_tenant_access
  before_action :set_tenant_context

  private

  def ensure_tenant_access
    unless current_user&.super_admin? || current_org_member?
      redirect_to root_path, alert: "Access denied. Organization membership required."
    end
  end

  def current_org_member?
    return true if current_user&.super_admin?
    return false unless current_organization
    current_user&.member_of?(current_organization)
  end

  def set_tenant_context
    byebug
    # Ensure we're in tenant context
    unless current_organization
      redirect_to root_path, alert: "No organization context available."
    end
  end

  def organization_admin?
    return true if current_user&.super_admin?
    current_user&.organization_admin?(current_organization)
  end

  def current_membership
    @current_membership ||= current_user&.organization_memberships&.active&.find_by(organization: current_organization)
  end

  def current_tenant_role
    current_membership&.organization_role
  end
end
