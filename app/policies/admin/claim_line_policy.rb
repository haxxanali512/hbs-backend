class Admin::ClaimLinePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "claim_lines", "index")
  end

  def show?
    accessible?("admin", "claim_lines", "show")
  end

  def update?
    accessible?("admin", "claim_lines", "update")
  end

  def edit?
    update?
  end

  # System-driven; exposed for role checks in actions
  def lock_on_submission?
    accessible?("admin", "claim_lines", "lock_on_submission")
  end

  def post_adjudication?
    accessible?("admin", "claim_lines", "post_adjudication")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
