class ActivationPolicy < ApplicationPolicy
  def index?
    return false unless current_org_member?
    accessible?("index", "organization_management_module", "activation")
  end

  def billing_setup?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "billing")
  end

  def compliance_setup?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "compliance")
  end

  def document_signing?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "activation")
  end

  def complete?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "activation")
  end

  def activate?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "activation")
  end
end
