class Admin::EncounterTemplatePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "encounter_templates", "index")
  end

  def show?
    accessible?("admin", "encounter_templates", "show")
  end

  def create?
    accessible?("admin", "encounter_templates", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "encounter_templates", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "encounter_templates", "destroy")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
