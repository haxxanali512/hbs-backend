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

  def update_billing?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "billing")
  end

  def update_compliance?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "compliance")
  end

  def complete_document_signing?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "activation")
  end

  def activation_complete?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "activation")
  end

  def save_stripe_card?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "billing")
  end

  def manual_payment?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "billing")
  end

  def stripe_card?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "billing")
  end

  def send_agreement?
    return false unless current_org_member?
    accessible?("update", "organization_management_module", "compliance")
  end

  def check_docusign_status?
    return false unless current_org_member?
    accessible?("show", "organization_management_module", "compliance")
  end
end
