class Tenant::PatientInsuranceCoveragePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "patient_insurance_coverages", "index")
  end

  def show?
    accessible?("tenant", "patient_insurance_coverages", "show")
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def create?
    accessible?("tenant", "patient_insurance_coverages", "create")
  end

  def update?
    accessible?("tenant", "patient_insurance_coverages", "update")
  end

  def destroy?
    accessible?("tenant", "patient_insurance_coverages", "destroy")
  end

  def activate?
    accessible?("tenant", "patient_insurance_coverages", "activate")
  end

  def terminate?
    accessible?("tenant", "patient_insurance_coverages", "terminate")
  end

  def replace?
    accessible?("tenant", "patient_insurance_coverages", "replace")
  end

  def run_eligibility?
    accessible?("tenant", "patient_insurance_coverages", "run_eligibility")
  end
end
