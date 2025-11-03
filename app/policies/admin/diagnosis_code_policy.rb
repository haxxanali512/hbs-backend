class Admin::DiagnosisCodePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "diagnosis_codes", "index")
  end

  def show?
    accessible?("admin", "diagnosis_codes", "show")
  end

  def create?
    accessible?("admin", "diagnosis_codes", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "diagnosis_codes", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "diagnosis_codes", "destroy")
  end

  def retire?
    accessible?("admin", "diagnosis_codes", "retire")
  end

  def activate?
    accessible?("admin", "diagnosis_codes", "activate")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
