class Tenant::ClaimPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "claims", "index")
  end

  def show?
    accessible?("tenant", "claims", "show")
  end

  def create?
    accessible?("tenant", "claims", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("tenant", "claims", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("tenant", "claims", "destroy")
  end

  def claim_insured_data?
    accessible?("tenant", "claims", "claim_insured_data")
  end

  def submit_claim_insured?
    accessible?("tenant", "claims", "submit_claim_insured")
  end

  def claim_data?
    accessible?("tenant", "claims", "claim_data")
  end

  def submit_claim?
    accessible?("tenant", "claims", "submit_claim")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
