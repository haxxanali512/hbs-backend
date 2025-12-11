# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # After successful password authentication, check if MFA is required
  def create
    self.resource = warden.authenticate!(auth_options)

    if resource.mfa_enabled?
      # Store user ID in session for OTP verification
      sign_out(resource)
      session[:mfa_user_id] = resource.id
      session[:mfa_remember_me] = params[:user][:remember_me] if params[:user]

      redirect_to users_mfa_verify_path
    else
      # Normal sign in without MFA
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  end
end

