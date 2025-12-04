class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :set_tenant_context, unless: -> { devise_controller? || controller_name == "notifications" }
  before_action :has_access?, unless: :devise_controller?
  helper_method :current_organization

  protected

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to request.referer || tenant_dashboard_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username, :first_name, :last_name ])
  end

  def pundit_user
    {
      user: current_user,
      organization: current_organization,
      membership: current_user&.organization_memberships&.active&.find_by(organization: current_organization)
    }
  end

  def has_access?
    return if [ "sessions", "passwords", "health", "invitations", "stripe", "gocardless", "notifications" ].include?(controller_name)

    authorize current_user, policy_class: "#{controller_path.classify}Policy".constantize
  end

  def find_org_by_subdomain
    subdomain = request.subdomain
    return nil if subdomain.blank? || subdomain == "www" || subdomain == "admin"
    Organization.find_by(subdomain: subdomain)
  end

  private

  def set_current_organization
    return unless user_signed_in?

    if Rails.env.production?
      org = find_org_by_subdomain
      if org
        @current_organization = org
      end
    else
      @current_organization = find_org_by_localhost
    end

    unless @current_organization
      @current_organization = current_user.organizations.first
    end
  end

  def current_organization
    @current_organization
  end

  def find_org_by_localhost
    subdomain = request.host.split(".").first
    Organization.find_by(subdomain: subdomain)
  end

  def user_organization_subdomain
    return nil if current_user.nil? || current_user.super_admin?

    membership = current_user.organization_memberships.active.first
    membership&.organization&.subdomain
  end


  def set_tenant_context
    # Only detect organization for tenant controllers
    if self.class.name.start_with?("Tenant::")
      @current_organization = detect_organization

      # Ensure organization is found for tenant controllers
      unless @current_organization
        redirect_to new_user_session_path, alert: "No organization context available."
        return
      end
    end

    TenantContext.with_context(
      user: current_user,
      organization: @current_organization,
      membership: current_user&.organization_memberships&.active&.find_by(organization: @current_organization)
    ) do
      yield
    end
  end

  private

  def detect_organization
    return nil unless user_signed_in?

    if Rails.env.production?
      org = find_org_by_subdomain
      return org if org
    else
      org = find_org_by_localhost
      return org if org
    end

    # Fallback to user's first organization
    current_user.organizations.first
  end
end
