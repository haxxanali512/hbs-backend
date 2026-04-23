class Admin::BaseController < ApplicationController
  before_action :ensure_super_admin_or_global_access
  before_action :set_global_context

  private

  def ensure_super_admin_or_global_access
    unless current_user&.super_admin? || current_user&.has_admin_access?
      redirect_to root_path, alert: "Access denied. Global admin privileges required."
    end
  end

  def set_global_context
    @current_organization = nil
    session[:portal_context] = "admin"
  end
end
