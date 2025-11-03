class Tenant::ClaimLinePolicy < ApplicationPolicy
  # Client users have no direct access to claim lines
  def index?
    false
  end

  def show?
    false
  end

  def update?
    false
  end

  def post_adjudication?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.none
    end
  end
end


