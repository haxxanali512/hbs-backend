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

  def checklist_step_completed(organization, step_name)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name,
      step_name: step_name
    }

    send_email_via_service(
      template_key: "organization.checklist_step_completed",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com",
      default_subject: "Activation Step Completed: #{step_name}",
      default_body_html: "<p>Hello #{owner&.first_name || 'there'},</p><p>The activation step '#{step_name}' has been completed for your organization #{organization.name}.</p><p>You can view your activation progress in your organization portal.</p>"
    )
  end

  def plan_step_completed(organization, plan, step_type)
    owner = organization.owner
    placeholders = {
      owner_first_name: owner&.first_name || owner&.email,
      organization_name: organization.name,
      plan_name: plan.insurance_plan&.name || "Plan",
      step_type: step_type.humanize
    }

    send_email_via_service(
      template_key: "organization.plan_step_completed",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "noreply@hbsdata.com",
      default_subject: "Plan Enrollment Step Completed: #{step_type.humanize}",
      default_body_html: "<p>Hello #{owner&.first_name || 'there'},</p><p>The enrollment step '#{step_type.humanize}' has been completed for plan '#{plan.insurance_plan&.name || 'Plan'}' in your organization #{organization.name}.</p><p>You can view your activation progress in your organization portal.</p>"
    )
  end
end
