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

  def approve?
    update?
  end

  def submit?
    create?
  end

  def cancel?
    update?
  end

  def resubmit?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
