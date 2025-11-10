class Admin::PayerEnrollmentPolicy < Admin::BasePolicy
  def index?
    true
  end

  def show?
    accessible?("admin", "payer_enrollments", "show")
  end

  def new?
    create?
  end

  def create?
    accessible?("admin", "payer_enrollments", "create")
  end

  def edit?
    update?
  end

  def update?
    accessible?("admin", "payer_enrollments", "update")
  end

  def destroy?
    accessible?("admin", "payer_enrollments", "destroy")
  end

  def submit?
    accessible?("admin", "payer_enrollments", "submit")
  end

  def cancel?
    accessible?("admin", "payer_enrollments", "cancel")
  end

  def resubmit?
    accessible?("admin", "payer_enrollments", "resubmit")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
