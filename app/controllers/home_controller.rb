class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    if user_signed_in?
      redirect_to dashboard_path
    end
  end

  def dashboard
    # Dashboard is protected by authenticate_user! from ApplicationController
    # Only super admins can access global dashboard
    unless current_user.super_admin?
      # Redirect tenant users to their organization's dashboard
      user_org = current_user.organization_memberships.active.first&.organization
      if user_org
        redirect_to "http://#{user_org.subdomain}.localhost:3000", allow_other_host: true
        return
      else
        redirect_to new_user_session_path, alert: "You don't have access to any organization."
        return
      end
    end

    # Global admin dashboard stats
    @users_count = User.count
    @roles_count = Role.count
  end
end
