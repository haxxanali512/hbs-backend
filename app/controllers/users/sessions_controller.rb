class Users::SessionsController < Devise::SessionsController
  layout "devise"
  skip_before_action :set_current_organization, only: [ :new, :create ]

  def create
    super do |resource|
      if resource.persisted?
        Rails.logger.info "User #{resource.email} signed in successfully"
        Rails.logger.info "User admin status: #{resource.admin?}"

        # Validate subdomain access for tenant users
        unless resource.super_admin?
          validate_subdomain_access(resource)
        end
      else
        Rails.logger.warn "Sign in failed for #{resource.email}: #{resource.errors.full_messages}"
      end
    end
  end

  private

  def validate_subdomain_access(resource)
    # Get organization from current subdomain
    current_subdomain = request.subdomain
    return if current_subdomain.blank? || [ "www", "admin" ].include?(current_subdomain)
    byebug
    org_from_subdomain = Organization.find_by(subdomain: current_subdomain)

    if org_from_subdomain.nil?
      Rails.logger.warn "User #{resource.email} tried to access non-existent subdomain: #{current_subdomain}"
      sign_out(resource)
      redirect_to new_user_session_path, alert: "Invalid organization subdomain. Please contact your administrator."
      return
    end

    # Check if user belongs to this organization
    unless resource.member_of?(org_from_subdomain)
      Rails.logger.warn "User #{resource.email} tried to access unauthorized organization: #{org_from_subdomain.name}"
      sign_out(resource)
      redirect_to new_user_session_path, alert: "You don't have access to #{org_from_subdomain.name}. Please contact your administrator."
      return
    end

    # Store validated organization in session for middleware
    session[:current_organization_id] = org_from_subdomain.id
    Rails.logger.info "User #{resource.email} validated for organization: #{org_from_subdomain.name}"
  end

  def after_sign_in_path_for(resource)
    if resource.super_admin?
      admin_dashboard_path
    else
      tenant_root_path
    end
  end

  def destroy
    # Clear organization session before logout
    session.delete(:current_organization_id)
    super
  end
end
