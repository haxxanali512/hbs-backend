class OrganizationMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  def organization_created(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.organization_created",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end

  def billing_setup_required(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.billing_setup_required",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end

  def compliance_setup_required(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.compliance_setup_required",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end

  def document_signing_required(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.document_signing_required",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end

  def organization_activated(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.organization_activated",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end

  def activation_completed(organization)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name
    }

    send_email_via_service(
      template_key: "organization.activation_completed",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com"
    )
  end
end
