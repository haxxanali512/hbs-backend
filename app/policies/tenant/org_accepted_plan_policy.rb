class Tenant::OrgAcceptedPlanPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "org_accepted_plans", "index")
  end

  def show?
    accessible?("tenant", "org_accepted_plans", "show")
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def create?
    accessible?("tenant", "org_accepted_plans", "create")
  end

  def update?
    accessible?("tenant", "org_accepted_plans", "update")
  end

  def destroy?
    # Cannot be hard-deleted; must be inactivated
    false
  end

  def activate?
    accessible?("tenant", "org_accepted_plans", "activate")
  end

  def inactivate?
    accessible?("tenant", "org_accepted_plans", "inactivate")
  end

  def lock?
    # Only HBS can lock
    false
  end

  def unlock?
    # Only HBS can unlock
    false
  end

  def update_enrollment_status?
    # Only HBS can update enrollment status
    false
  end
end
