module Admin
  class DashboardPolicy < ApplicationPolicy
    def index?
      accessible?("admin", "dashboard", "index")
    end
  end
end
