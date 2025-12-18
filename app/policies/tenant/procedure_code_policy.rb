class Tenant::ProcedureCodePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "procedure_codes", "index")
  end

  def show?
    accessible?("tenant", "procedure_codes", "show")
  end

  def search?
    index?
  end

  class Scope < Scope
    def resolve
      scope.active
    end
  end
end
