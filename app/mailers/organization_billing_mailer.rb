class OrganizationBillingMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  # Email sent to super admins when a manual payment request is submitted
  def manual_payment_request(organization_billing)
    @organization = organization_billing.organization
    @organization_billing = organization_billing
    @owner = @organization.owner

    # Get all super admin emails
    super_admin_emails = User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)

    mail(
      to: super_admin_emails,
      subject: "Manual Payment Request - #{@organization.name}",
      reply_to: @owner.email
    )
  end

  # Email sent to organization owner when their manual payment is approved
  def manual_payment_approved(organization_billing)
    @organization = organization_billing.organization
    @organization_billing = organization_billing
    @owner = @organization.owner

    mail(
      to: @owner.email,
      subject: "Payment Approved - #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent to organization owner when their manual payment is rejected
  def manual_payment_rejected(organization_billing)
    @organization = organization_billing.organization
    @organization_billing = organization_billing
    @owner = @organization.owner

    mail(
      to: @owner.email,
      subject: "Payment Rejected - #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent to organization owner when billing setup is completed (for non-manual methods)
  def billing_setup_completed(organization_billing)
    @organization = organization_billing.organization
    @organization_billing = organization_billing
    @owner = @organization.owner

    mail(
      to: @owner.email,
      subject: "Billing Setup Complete - #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end
end
