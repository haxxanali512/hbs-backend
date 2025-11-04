class Admin::ClaimSubmissionPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "claim_submissions", "index")
  end

  def show?
    accessible?("admin", "claim_submissions", "show")
  end

  def create?
    accessible?("admin", "claim_submissions", "create")
  end

  def resubmit?
    accessible?("admin", "claim_submissions", "resubmit")
  end

  def void?
    accessible?("admin", "claim_submissions", "void")
  end

  def replace?
    accessible?("admin", "claim_submissions", "replace")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
