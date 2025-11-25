class OrganizationBillingMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  def manual_payment_request(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    super_admin_emails = User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)

    amount_value = organization_billing.try(:amount_due) || organization_billing.try(:amount) || organization_billing.try(:total_amount)
    placeholders = {
      organization_name: organization.name,
      owner_name: owner&.full_name || owner&.email,
      billing_period: organization_billing.billing_period || organization_billing.created_at.strftime("%B %Y"),
      amount_requested: amount_value
    }

    send_email_via_service(
      template_key: "billing.manual_payment_request",
      to: super_admin_emails,
      placeholders: placeholders,
      reply_to: owner&.email
    )
  end

  def manual_payment_approved(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "billing.manual_payment_approved",
      to: owner.email,
      placeholders: placeholders
    )
  end

  def manual_payment_rejected(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner

    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "billing.manual_payment_rejected",
      to: owner.email,
      placeholders: placeholders
    )
  end

  def billing_setup_completed(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner

    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "billing.billing_setup_completed",
      to: owner.email,
      placeholders: placeholders
    )
  end
end
