class OrganizationMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  # Email sent when organization is created
  def organization_created(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "Welcome! Your organization '#{@organization.name}' has been created",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent when billing setup step is reached
  def billing_setup_required(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "Next Step: Complete Billing Setup for #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent when compliance setup step is reached
  def compliance_setup_required(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "Next Step: Complete Compliance Setup for #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent when document signing step is reached
  def document_signing_required(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "Next Step: Sign Documents for #{@organization.name}",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent when organization is fully activated
  def organization_activated(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "🎉 Congratulations! #{@organization.name} is now fully activated",
      reply_to: "noreply@hbsdata.com"
    )
  end

  # Email sent when activation is completed (final step)
  def activation_completed(organization)
    @organization = organization
    @owner = organization.owner

    mail(
      to: @owner.email,
      subject: "✅ Activation Complete - #{@organization.name} is ready to use",
      reply_to: "noreply@hbsdata.com"
    )
  end
end
