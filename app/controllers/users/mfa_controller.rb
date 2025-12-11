# frozen_string_literal: true

class Users::MfaController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :has_access?

  # GET /users/mfa - Show MFA setup page
  def show
    @mfa_enabled = current_user.mfa_enabled?
  end

  # POST /users/mfa/enable - Start MFA setup (generate secret)
  def enable
    if current_user.mfa_enabled?
      redirect_to users_mfa_path, alert: "MFA is already enabled."
      return
    end

    # Generate new OTP secret but don't enable yet
    current_user.otp_secret = User.generate_otp_secret
    current_user.save!

    @qr_code_svg = current_user.mfa_qr_code_svg
    @otp_secret = current_user.otp_secret

    render :setup
  end

  # POST /users/mfa/verify - Verify OTP and complete MFA setup
  def verify
    otp_code = params[:otp_code]

    if current_user.validate_and_consume_otp!(otp_code)
      current_user.update!(otp_required_for_login: true)
      redirect_to users_mfa_path, notice: "🔐 Two-factor authentication has been enabled successfully!"
    else
      # Re-render setup with error
      @qr_code_svg = current_user.mfa_qr_code_svg
      @otp_secret = current_user.otp_secret
      flash.now[:alert] = "Invalid verification code. Please try again."
      render :setup
    end
  end

  # DELETE /users/mfa - Disable MFA
  def disable
    password = params[:password]

    unless current_user.valid_password?(password)
      redirect_to users_mfa_path, alert: "Incorrect password. MFA was not disabled."
      return
    end

    current_user.disable_mfa!
    redirect_to users_mfa_path, notice: "Two-factor authentication has been disabled."
  end
end

