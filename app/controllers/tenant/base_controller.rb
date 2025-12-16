class Tenant::BaseController < ApplicationController
  before_action :ensure_tenant_access

  private

  def ensure_tenant_access
    # Allow access if user is a member of the organization OR if they're masquerading
    unless current_org_member? || (respond_to?(:user_masquerade?) && user_masquerade?)
      reset_session
      redirect_to new_user_session_path, alert: "Access denied. Organization membership required."
    end
  end

  def current_org_member?
    current_user&.member_of?(current_organization)
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
