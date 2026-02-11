class Admin::OrgAcceptedPlanPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "org_accepted_plans", "index")
  end

  def show?
    accessible?("admin", "org_accepted_plans", "show")
  end

  def new?
    create?
  end

  def create?
    accessible?("admin", "org_accepted_plans", "create")
  end

  def edit?
    update?
  end

  def update?
    accessible?("admin", "org_accepted_plans", "update")
  end

  def destroy?
    # Cannot be hard-deleted; must be inactivated
    false
  end

  def activate?
    accessible?("admin", "org_accepted_plans", "activate")
  end

  def approve_enrollment?
    update?
  end

  def deny_enrollment?
    update?
  end

  def inactivate?
    accessible?("admin", "org_accepted_plans", "inactivate")
  end

  def lock?
    accessible?("admin", "org_accepted_plans", "lock")
  end

  def unlock?
    accessible?("admin", "org_accepted_plans", "unlock")
  end

  def update_enrollment_status?
    accessible?("admin", "org_accepted_plans", "update_enrollment_status")
  end
end
