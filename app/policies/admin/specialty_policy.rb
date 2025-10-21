class Admin::SpecialtyPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "specialties", "index")
  end

  def show?
    accessible?("admin", "specialties", "show")
  end

  def create?
    accessible?("admin", "specialties", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "specialties", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "specialties", "destroy")
  end

  def retire?
    accessible?("admin", "specialties", "update")
  end

  def impact_analysis?
    accessible?("admin", "specialties", "show")
  end

  def list_providers?
    accessible?("admin", "specialties", "show")
  end

  def update_allowed_codes?
    accessible?("admin", "specialties", "update")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
