class Admin::BaseController < ApplicationController
  before_action :ensure_super_admin_or_global_access
  before_action :set_global_context

  private

  def ensure_super_admin_or_global_access
    unless current_user&.super_admin? || has_global_access?
      redirect_to root_path, alert: "Access denied. Global admin privileges required."
    end
  end

  def has_global_access?
    # Check if user has global role permissions
    current_user&.role&.global? &&
    current_user&.role&.access&.dig("users_management_module", "dashboard", "index")
  end

  def set_global_context
    @current_organization = nil
  end
end
