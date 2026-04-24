class Users::SessionsController < Devise::SessionsController
  skip_before_action :require_no_authentication, only: [ :new ]

  def new
    clear_mismatched_tenant_session!

    if user_signed_in?
      redirect_to signed_in_destination_for(current_user), allow_other_host: true
      return
    end

    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    yield resource if block_given?
    render :new
  end

  def create
    if tenant_login_rejected?
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      set_flash_message!(:alert, :invalid)
      respond_with_navigational(resource) { render :new, status: :unprocessable_entity }
      return
    end

    super
  end

  private

  def respond_with(resource, _opts = {})
    redirect_to after_sign_in_path_for(resource), allow_other_host: true
  end

  def tenant_login_rejected?
    tenant = requested_tenant
    return false if tenant.blank?

    user = User.find_for_database_authentication(email: sign_in_params[:email].to_s.downcase.strip)
    return true if user.blank?

    !user_belongs_to_tenant?(user, tenant)
  end

  def requested_tenant
    subdomain = request.subdomain.to_s.strip.downcase
    return nil if subdomain.blank? || %w[www admin referral].include?(subdomain)

    Organization.find_by(subdomain: subdomain)
  end

  def clear_mismatched_tenant_session!
    tenant = requested_tenant
    return if tenant.blank?

    signed_in_user = current_user
    return unless signed_in_user
    return if user_belongs_to_tenant?(signed_in_user, tenant)

    sign_out_all_scopes
    reset_session
  end

  def user_belongs_to_tenant?(user, tenant)
    user.organization_memberships.active.exists?(organization: tenant) ||
      user.organizations.exists?(id: tenant.id)
  end

  def signed_in_destination_for(user)
    if request.subdomain == "referral" && user.has_referral_partner_access?
      referral_portal_url_for("/dashboard")
    elsif (tenant = requested_tenant).present? && user_belongs_to_tenant?(user, tenant)
      if Rails.env.development?
        "http://#{tenant.subdomain}.hbs.localhost:3000/tenant/dashboard"
      else
        "#{request.protocol}#{tenant.subdomain}.#{base_portal_host}/tenant/dashboard"
      end
    else
      after_sign_in_path_for(user)
    end
  end
end
