module Tenant
  class DashboardPolicy < ApplicationPolicy
    def index?
      accessible?("tenant", "dashboard", "index")
    end
  end
end
