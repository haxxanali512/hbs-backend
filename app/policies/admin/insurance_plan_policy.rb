module Admin
  class InsurancePlanPolicy < ApplicationPolicy
    def index?
      accessible?("admin", "insurance_plans", "index")
    end

    def show?
      accessible?("admin", "insurance_plans", "show")
    end

    def new?
      create?
    end

    def edit?
      update?
    end

    def create?
      accessible?("admin", "insurance_plans", "create")
    end

    def update?
      accessible?("admin", "insurance_plans", "update")
    end

    def destroy?
      accessible?("admin", "insurance_plans", "destroy")
    end

    def retire?
      accessible?("admin", "insurance_plans", "update")
    end

    def restore?
      accessible?("admin", "insurance_plans", "update")
    end

    def view_audit?
      accessible?("admin", "insurance_plans", "show")
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.all
      end
    end
  end
end
