class Admin::PrescriptionPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "prescriptions", "index")
  end

  def show?
    accessible?("admin", "prescriptions", "show")
  end
end

