class Admin::PatientInsuranceCoveragePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "patient_insurance_coverages", "index")
  end

  def show?
    accessible?("admin", "patient_insurance_coverages", "show")
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def create?
    accessible?("admin", "patient_insurance_coverages", "create")
  end

  def update?
    accessible?("admin", "patient_insurance_coverages", "update")
  end

  def destroy?
    accessible?("admin", "patient_insurance_coverages", "destroy")
  end

  def activate?
    accessible?("admin", "patient_insurance_coverages", "activate")
  end

  def terminate?
    accessible?("admin", "patient_insurance_coverages", "terminate")
  end

  def replace?
    accessible?("admin", "patient_insurance_coverages", "replace")
  end

  def run_eligibility?
    accessible?("admin", "patient_insurance_coverages", "run_eligibility")
  end
end
