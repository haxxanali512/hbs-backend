class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Catch 500-level errors and send email notifications
  rescue_from StandardError, with: :handle_server_error
  before_action :set_impersonation_ended_flash
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :set_tenant_context, unless: -> { devise_controller? || controller_name == "notifications" }
  before_action :has_access?, unless: :devise_controller?
  helper_method :current_organization, :current_organization_date, :current_organization_time_zone, :format_in_organization_tz

  protected

  # Today's date in the current organization's time zone (for default encounter date, etc.).
  # In tenant context this uses the org's setting; otherwise falls back to Date.current.
  def current_organization_date
    return Date.current unless current_organization

    tz = current_organization.organization_setting&.effective_time_zone
    tz = OrganizationSetting::DEFAULT_TIME_ZONE if tz.blank?
    zone = ActiveSupport::TimeZone[tz] || ActiveSupport::TimeZone[OrganizationSetting::DEFAULT_TIME_ZONE]
    zone ? zone.today : Date.current
  end

  # ActiveSupport::TimeZone for the current organization (for formatting datetimes in tables/detail pages).
  def current_organization_time_zone
    return Time.zone unless current_organization

    tz = current_organization.organization_setting&.effective_time_zone
    tz = OrganizationSetting::DEFAULT_TIME_ZONE if tz.blank?
    ActiveSupport::TimeZone[tz] || ActiveSupport::TimeZone[OrganizationSetting::DEFAULT_TIME_ZONE] || Time.zone
  end

  # Format a datetime in the organization's time zone for display in tenant tables and detail pages.
  # Pass optional format string (default long datetime); returns "—" if datetime is blank.
  def format_in_organization_tz(datetime, format_string = "%B %d, %Y at %I:%M %p")
    return "—" if datetime.blank?

    zone = current_organization_time_zone
    datetime.respond_to?(:in_time_zone) ? datetime.in_time_zone(zone).strftime(format_string) : datetime.to_s
  end

  def set_impersonation_ended_flash
    return unless params[:impersonation_ended].present?
    flash[:notice] = "You have stopped impersonating. Sign in to the admin portal if needed."
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to request.referer || tenant_dashboard_path
  end

  def handle_server_error(exception)
    # Authorization failures should be treated as 403 with a friendly message,
    # not as 500-level server errors.
    if exception.is_a?(Pundit::NotAuthorizedError)
      user_not_authorized
      return
    end

    # Skip email notification in development if showing local errors
    unless Rails.env.development? && config.consider_all_requests_local
      # Send error notification email
      ErrorNotificationService.notify(
        exception,
        request: request,
        context: {
          user_id: current_user&.id,
          organization_id: current_organization&.id
        }
      )
    end

    # Log the error
    Rails.logger.error "Server Error: #{exception.class.name} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    # Render error response only if response hasn't been committed
    return if response.committed?

    # Check if respond_to was already called by checking if format is set
    if request.format.html?
      render plain: "Internal Server Error", status: :internal_server_error
    elsif request.format.json?
      render json: { error: "Internal server error" }, status: :internal_server_error
    elsif request.format.turbo_stream?
      render plain: "Internal Server Error", status: :internal_server_error
    else
      # Default to HTML if format is not set
      render plain: "Internal Server Error", status: :internal_server_error
    end
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

    # Use organization time zone for all date/time in the request (tenant only)
    if @current_organization
      tz = @current_organization.organization_setting&.effective_time_zone
      tz = OrganizationSetting::DEFAULT_TIME_ZONE if tz.blank?
      Time.zone = ActiveSupport::TimeZone[tz] || ActiveSupport::TimeZone[OrganizationSetting::DEFAULT_TIME_ZONE]
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
      # Subdomain didn't match any org — don't fall back; user will get "No organization context"
      return nil
    end

    org = find_org_by_localhost
    return org if org
    # Development: only fall back to user's first org when on plain localhost (no subdomain)
    # so /tenant/dashboard works. If we had a subdomain in the host and it didn't match, don't assign wrong org.
    on_plain_localhost = (request.host == "localhost" || request.host.start_with?("127.0.0.1")) && request.subdomain.blank?
    on_plain_localhost ? current_user.organizations.first : nil
  end
end
