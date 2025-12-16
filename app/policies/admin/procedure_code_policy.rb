class Admin::ProcedureCodePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "procedure_codes", "index")
  end

  def show?
    accessible?("admin", "procedure_codes", "show")
  end

  def create?
    accessible?("admin", "procedure_codes", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "procedure_codes", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "procedure_codes", "destroy")
  end

  def push_to_ezclaim?
    create?
  end

  def toggle_status?
    accessible?("admin", "procedure_codes", "update")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
