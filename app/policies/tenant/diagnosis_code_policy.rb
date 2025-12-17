class Tenant::DiagnosisCodePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "diagnosis_codes", "index")
  end

  def show?
    accessible?("tenant", "diagnosis_codes", "show")
  end

  def request?
    accessible?("tenant", "diagnosis_codes", "request")
  end

  def search?
    index?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.active
    end
  end
end
