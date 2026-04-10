module Tenant
  class DashboardPolicy < ApplicationPolicy
    def index?
      accessible?("tenant", "dashboard", "index")
    end

    def client_directory?
      true
    end
  end
end
