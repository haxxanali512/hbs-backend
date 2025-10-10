class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_current_organization
  around_action :set_tenant_context, unless: :devise_controller?

  helper_method :current_organization

  protected

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

  def find_org_by_subdomain
    subdomain = request.subdomain
    return nil if subdomain.blank? || subdomain == "www" || subdomain == "admin"
    Organization.find_by(subdomain: subdomain)
  end

  private

  def set_current_organization
    # byebug
    return unless user_signed_in?

    # Skip organization setup for super admins on global domains
    if current_user.super_admin? && [ "www", "admin", "" ].include?(request.subdomain)
      @current_organization = nil
      return
    end

    # For tenant users, use session-stored organization if available
    if session[:current_organization_id]
      session_org = Organization.find_by(id: session[:current_organization_id])

        if session_org && current_user.member_of?(session_org)
          # Verify subdomain matches session organization
          subdomain_matches = Rails.env.production? ? request.subdomain == session_org.subdomain : request.host.include?("#{session_org.subdomain}.")

          if subdomain_matches
            @current_organization = session_org
          else
            # User is on wrong subdomain or root domain, redirect to their organization
            if request.subdomain.blank?
              Rails.logger.info "User #{current_user.email} accessing root domain, redirecting to organization: #{session_org.subdomain}"
            else
              Rails.logger.warn "User #{current_user.email} tried to access wrong subdomain: #{request.subdomain} (belongs to: #{session_org.subdomain})"
            end
            redirect_to "http://#{session_org.subdomain}.localhost:3000", allow_other_host: true
            nil
          end
        else
        # Session organization invalid, clear and redirect to login
        session.delete(:current_organization_id)
        redirect_to new_user_session_path, alert: "Session expired. Please log in again."
        nil
        end
    else
      # No session organization - for already signed in users, set it up
      user_org = current_user.organization_memberships.active.first&.organization
      if user_org
        # Set the organization in session and redirect to correct subdomain
        session[:current_organization_id] = user_org.id
        redirect_to "http://#{user_org.subdomain}.localhost:3000", allow_other_host: true
        nil
      else
        # User has no organization, sign them out and redirect to login
        sign_out(current_user)
        redirect_to new_user_session_path, alert: "You don't have access to any organization."
        nil
      end
    end
  end

  def current_organization
    @current_organization
  end




  def user_organization_subdomain
    return nil if current_user.nil? || current_user.super_admin?

    membership = current_user.organization_memberships.active.first
    membership&.organization&.subdomain
  end


  def set_tenant_context
    byebug
    TenantContext.with_context(
      user: current_user,
      organization: current_organization,
      membership: current_user&.organization_memberships&.active&.find_by(organization: current_organization)
    ) do
      yield
    end
  end
end
