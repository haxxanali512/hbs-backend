class Tenant::BaseController < ApplicationController
  before_action :ensure_tenant_access

  private

  def ensure_tenant_access
    # Tenant portal is restricted to:
    #   1. Active members of the current organization, OR
    #   2. Admins actively impersonating (masquerading) a tenant user.
    # A Super Admin signed in directly cannot access tenant dashboards by just
    # changing the subdomain; they must impersonate a tenant user.
    return if impersonating?
    return if current_org_member?

    reset_session
    redirect_to new_user_session_path, alert: "Access denied. Organization membership required."
  end

  def current_org_member?
    return false unless current_user && current_organization

    current_user.organization_memberships
                .active
                .exists?(organization: current_organization)
  end

  def impersonating?
    respond_to?(:user_masquerade?) && user_masquerade?
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
