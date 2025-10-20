module Admin
  class RolePolicy < ApplicationPolicy
    def index?
      accessible?("admin", "roles", "index")
    end

    def edit?
      accessible?("admin", "roles", "update")
    end

    def show?
      accessible?("admin", "roles", "show")
    end

    def create?
      accessible?("admin", "roles", "create")
    end

    def update?
      accessible?("admin", "roles", "update")
    end

    def destroy?
      accessible?("admin", "roles", "destroy")
    end

    def permissions?
      accessible?("admin", "roles", "update")
    end

    def duplicate?
      accessible?("admin", "roles", "create")
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.all
      end
    end
  end
end
