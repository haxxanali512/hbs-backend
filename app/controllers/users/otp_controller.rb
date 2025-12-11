# frozen_string_literal: true

class Users::OtpController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :has_access?
  before_action :ensure_mfa_session

  # GET /users/mfa/verify - Show OTP input form
  def new
    @user = User.find(session[:mfa_user_id])
  end

  # POST /users/mfa/authenticate - Verify OTP code
  def create
    @user = User.find(session[:mfa_user_id])
    otp_code = params[:otp_code]

    if @user.validate_and_consume_otp!(otp_code)
      # Clear MFA session data
      remember_me = session.delete(:mfa_remember_me)
      session.delete(:mfa_user_id)

      # Sign in the user
      sign_in(@user)
      @user.remember_me! if remember_me == "1"

      redirect_to after_sign_in_path_for(@user), notice: "Signed in successfully."
    else
      flash.now[:alert] = "Invalid verification code. Please try again."
      render :new
    end
  end

  # GET /users/mfa/resend - For future: resend backup code or email OTP
  def resend
    redirect_to users_mfa_verify_path, notice: "Please use your authenticator app to generate a new code."
  end

  private

  def ensure_mfa_session
    unless session[:mfa_user_id].present?
      redirect_to new_user_session_path, alert: "Please sign in first."
    end
  end
end

