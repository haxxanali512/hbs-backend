class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    if user_signed_in?
      redirect_to dashboard_path
    end
  end

  def dashboard
    # Dashboard is protected by authenticate_user! from ApplicationController
    @users_count = User.count
    @roles_count = Role.count
  end
end
