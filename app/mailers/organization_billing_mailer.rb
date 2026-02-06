class OrganizationBillingMailer < ApplicationMailer
  default from: "support@holisticbusinesssolution.com"

  def manual_payment_request(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    super_admin_emails = User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)
    return if super_admin_emails.blank?

    amount_value = organization_billing.try(:amount_due) || organization_billing.try(:amount) || organization_billing.try(:total_amount)
    ph = {
      organization_name: organization.name,
      owner_name: owner&.full_name || owner&.email,
      billing_period: organization_billing.billing_period || organization_billing.created_at.strftime("%B %Y"),
      amount_requested: amount_value
    }
    html = interpolate("<p>Manual payment request for organization <strong>{{organization_name}}</strong> (owner: {{owner_name}}). Billing period: {{billing_period}}. Amount requested: {{amount_requested}}.</p>", ph)
    text = interpolate("Manual payment request for organization {{organization_name}} (owner: {{owner_name}}). Billing period: {{billing_period}}. Amount requested: {{amount_requested}}.", ph)

    mail(to: super_admin_emails, reply_to: owner&.email, subject: "Manual payment request: #{organization.name}") do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end

  def manual_payment_approved(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    return if owner.blank?

    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    html = interpolate("<p>Hello {{owner_first_name}},</p><p>Your manual payment for <strong>{{organization_name}}</strong> has been approved.</p>", ph)
    text = interpolate("Hello {{owner_first_name}}, Your manual payment for {{organization_name}} has been approved.", ph)

    mail(to: owner.email, subject: "Payment approved: #{organization.name}") do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end

  def manual_payment_rejected(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    return if owner.blank?

    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    html = interpolate("<p>Hello {{owner_first_name}},</p><p>Your manual payment for <strong>{{organization_name}}</strong> has been rejected. Please contact support if you have questions.</p>", ph)
    text = interpolate("Hello {{owner_first_name}}, Your manual payment for {{organization_name}} has been rejected. Please contact support if you have questions.", ph)

    mail(to: owner.email, subject: "Payment rejected: #{organization.name}") do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end

  def billing_setup_completed(organization_billing)
    organization = organization_billing.organization
    owner = organization.owner
    return if owner.blank?

    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    html = interpolate("<p>Hello {{owner_first_name}},</p><p>Billing setup has been completed for your organization <strong>{{organization_name}}</strong>.</p>", ph)
    text = interpolate("Hello {{owner_first_name}}, Billing setup has been completed for your organization {{organization_name}}.", ph)

    mail(to: owner.email, subject: "Billing setup completed: #{organization.name}") do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end
end
