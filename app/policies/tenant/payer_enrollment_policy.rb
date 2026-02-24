class Tenant::PayerEnrollmentPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "payer_enrollments", "index")
  end
end
