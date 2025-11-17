class Admin::ClaimPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "claims", "index")
  end

  def show?
    accessible?("admin", "claims", "show")
  end

  def create?
    accessible?("admin", "claims", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "claims", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "claims", "destroy")
  end

  def validate?
    accessible?("admin", "claims", "validate")
  end

  def submit?
    accessible?("admin", "claims", "submit")
  end

  def post_adjudication?
    accessible?("admin", "claims", "post_adjudication")
  end

  def void?
    accessible?("admin", "claims", "void")
  end

  def test_ezclaim_connection?
    accessible?("admin", "claims", "submit")
  end

  def reverse?
    accessible?("admin", "claims", "reverse")
  end

  def close?
    accessible?("admin", "claims", "close")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
