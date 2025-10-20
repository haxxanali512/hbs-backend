module Admin
  class UserPolicy < ApplicationPolicy
    def index?
      accessible?("admin", "users", "index")
    end

    def show?
      accessible?("admin", "users", "show")
    end

    def new?
      accessible?("admin", "users", "create")
    end

    def create?
      accessible?("admin", "users", "create")
    end

    def update?
      accessible?("admin", "users", "update")
    end

    def destroy?
      accessible?("admin", "users", "destroy")
    end

    def invite?
      accessible?("admin", "users", "create")
    end

    def reinvite?
      accessible?("admin", "users", "update")
    end

    def reset_password?
      accessible?("admin", "users", "update")
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.super_admin?
          scope.all
        else
          scope.where(id: user.id)
        end
      end
    end
  end
end
