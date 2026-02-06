class OrganizationMailer < ApplicationMailer
  helper :application
  include Devise::Controllers::UrlHelpers
  default from: "support@holisticbusinesssolution.com"

  def organization_created(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Your organization has been created",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Your organization <strong>{{organization_name}}</strong> has been created in Holistic Business Solutions.</p><p>You can sign in to complete setup from your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, Your organization {{organization_name}} has been created in Holistic Business Solutions. You can sign in to complete setup from your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def billing_setup_required(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Billing setup required for #{organization.name}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Your organization <strong>{{organization_name}}</strong> requires billing setup. Please complete this step in your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, Your organization {{organization_name}} requires billing setup. Please complete this step in your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def compliance_setup_required(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Compliance setup required for #{organization.name}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Your organization <strong>{{organization_name}}</strong> requires compliance setup. Please complete this step in your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, Your organization {{organization_name}} requires compliance setup. Please complete this step in your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def document_signing_required(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Document signing required for #{organization.name}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Your organization <strong>{{organization_name}}</strong> has documents that require your signature. Please sign in to your organization portal to complete them.</p>",
      body_text: "Hello {{owner_first_name}}, Your organization {{organization_name}} has documents that require your signature. Please sign in to your organization portal to complete them.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def organization_activated(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Your organization has been activated",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Your organization <strong>{{organization_name}}</strong> has been activated. You can now use all features in your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, Your organization {{organization_name}} has been activated. You can now use all features in your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def activation_completed(organization)
    owner = organization.owner
    return if owner.blank?
    ph = { owner_first_name: owner.first_name.presence || owner.email, organization_name: organization.name }
    direct_mail(
      to: owner.email,
      subject: "Activation completed for #{organization.name}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>Activation has been completed for your organization <strong>{{organization_name}}</strong>. Thank you for completing the setup.</p>",
      body_text: "Hello {{owner_first_name}}, Activation has been completed for your organization {{organization_name}}. Thank you for completing the setup.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def checklist_step_completed(organization, step_name)
    owner = organization.owner
    return if owner.blank?
    ph = {
      owner_first_name: owner.first_name.presence || owner.email,
      organization_name: organization.name,
      step_name: step_name
    }
    direct_mail(
      to: owner.email,
      subject: "Activation Step Completed: #{step_name}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>The activation step '{{step_name}}' has been completed for your organization {{organization_name}}.</p><p>You can view your activation progress in your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, The activation step '{{step_name}}' has been completed for your organization {{organization_name}}. You can view your activation progress in your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def provider_approved(provider)
    organization = provider.organizations.first
    return if organization.blank? || organization.owner.blank?
    ph = { provider_name: provider.full_name, organization_name: organization.name }
    direct_mail(
      to: organization.owner.email,
      subject: "Provider approved: #{provider.full_name}",
      body_html: "<p>Provider <strong>{{provider_name}}</strong> has been approved and is now active for {{organization_name}}.</p>",
      body_text: "Provider {{provider_name}} has been approved and is now active for {{organization_name}}.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def provider_rejected(provider)
    organization = provider.organizations.first
    return if organization.blank? || organization.owner.blank?
    ph = { provider_name: provider.full_name, organization_name: organization.name }
    direct_mail(
      to: organization.owner.email,
      subject: "Provider rejected: #{provider.full_name}",
      body_html: "<p>Provider <strong>{{provider_name}}</strong> has been rejected for {{organization_name}}.</p>",
      body_text: "Provider {{provider_name}} has been rejected for {{organization_name}}.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def provider_suspended(provider)
    organization = provider.organizations.first
    return if organization.blank? || organization.owner.blank?
    ph = { provider_name: provider.full_name, organization_name: organization.name }
    direct_mail(
      to: organization.owner.email,
      subject: "Provider suspended: #{provider.full_name}",
      body_html: "<p>Provider <strong>{{provider_name}}</strong> has been suspended for {{organization_name}}.</p>",
      body_text: "Provider {{provider_name}} has been suspended for {{organization_name}}.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def provider_reactivated(provider)
    organization = provider.organizations.first
    return if organization.blank? || organization.owner.blank?
    ph = { provider_name: provider.full_name, organization_name: organization.name }
    direct_mail(
      to: organization.owner.email,
      subject: "Provider reactivated: #{provider.full_name}",
      body_html: "<p>Provider <strong>{{provider_name}}</strong> has been reactivated for {{organization_name}}.</p>",
      body_text: "Provider {{provider_name}} has been reactivated for {{organization_name}}.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def provider_deactivated(provider)
    organization = provider.organizations.first
    return if organization.blank? || organization.owner.blank?
    ph = { provider_name: provider.full_name, organization_name: organization.name }
    direct_mail(
      to: organization.owner.email,
      subject: "Provider deactivated: #{provider.full_name}",
      body_html: "<p>Provider <strong>{{provider_name}}</strong> has been deactivated for {{organization_name}}.</p>",
      body_text: "Provider {{provider_name}} has been deactivated for {{organization_name}}.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  def plan_step_completed(organization, plan, step_type)
    owner = organization.owner
    return if owner.blank?
    plan_name = plan.insurance_plan&.name || "Plan"
    ph = {
      owner_first_name: owner.first_name.presence || owner.email,
      organization_name: organization.name,
      plan_name: plan_name,
      step_type: step_type.to_s.humanize
    }
    direct_mail(
      to: owner.email,
      subject: "Plan Enrollment Step Completed: #{step_type.to_s.humanize}",
      body_html: "<p>Hello {{owner_first_name}},</p><p>The enrollment step '{{step_type}}' has been completed for plan '{{plan_name}}' in your organization {{organization_name}}.</p><p>You can view your activation progress in your organization portal.</p>",
      body_text: "Hello {{owner_first_name}}, The enrollment step '{{step_type}}' has been completed for plan '{{plan_name}}' in your organization {{organization_name}}. You can view your activation progress in your organization portal.",
      placeholders: ph,
      reply_to: "support@holisticbusinesssolution.com"
    )
  end

  # Custom first-time access email for org owners when an org is activated directly.
  def owner_activation_invite(organization, invitation_token)
    owner = organization.owner
    return if owner.nil?

    if Rails.env.development?
      tenant_host = "#{organization.subdomain}.localhost"
      protocol = "http"
      port = ActionMailer::Base.default_url_options[:port] || 3000
    else
      tenant_host = "#{organization.subdomain}.holisticbusinesssolution.net"
      protocol = "https"
      port = nil
    end

    url_opts = { host: tenant_host, protocol: protocol }
    url_opts[:port] = port if port.present?

    begin
      invite_link = accept_user_invitation_url(url_opts.merge(invitation_token: invitation_token))
    rescue => e
      Rails.logger.error "[OrganizationMailer] Failed to build invite URL: #{e.message}"
      base_url = port.present? ? "#{protocol}://#{tenant_host}:#{port}" : "#{protocol}://#{tenant_host}"
      invite_link = "#{base_url}/users/invitation/accept?invitation_token=#{invitation_token}"
    end

    portal_url = port.present? ? "#{protocol}://#{tenant_host}:#{port}" : "#{protocol}://#{tenant_host}"
    subdomain_display = Rails.env.development? ? "#{organization.subdomain}.localhost:3000" : "#{organization.subdomain}.holisticbusinesssolution.net"

    ph = {
      owner_first_name: owner.first_name.presence || owner.email,
      organization_name: organization.name,
      invite_link: invite_link,
      portal_url: portal_url,
      subdomain_display: subdomain_display
    }

    html = interpolate(<<~HTML, ph)
      <p>Hello {{owner_first_name}},</p>
      <p>Your organization <strong>{{organization_name}}</strong> has been activated in Holistic Business Solutions.</p>
      <p>To access your portal for the first time:</p>
      <ol>
        <li>Click the button below to accept your invitation and set your password.</li>
        <li>After setting your password, you'll be taken directly to your organization portal.</li>
      </ol>
      <p style="text-align:center;margin:24px 0;">
        <a href="{{invite_link}}" style="display:inline-block;background:#4f46e5;color:white;padding:12px 20px;text-decoration:none;border-radius:8px;font-weight:600;">
          Accept Invitation &amp; Set Password
        </a>
      </p>
      <p><strong>Organization Portal URL:</strong> {{portal_url}}<br/>
         <strong>Tenant domain:</strong> {{subdomain_display}}</p>
      <p>You can bookmark this URL and use it any time to sign in.</p>
      <p>If you did not expect this email, you can safely ignore it.</p>
    HTML

    text = interpolate(<<~TEXT, ph)
      Hello {{owner_first_name}},

      Your organization {{organization_name}} has been activated in Holistic Business Solutions.

      To access your portal for the first time:

      1) Open this link to accept your invitation and set your password:
         {{invite_link}}

      2) After setting your password, you will be taken directly to your organization portal.

      Organization Portal URL: {{portal_url}}
      Tenant domain: {{subdomain_display}}

      You can bookmark this URL and use it any time to sign in.

      If you did not expect this email, you can safely ignore it.
    TEXT

    mail(
      to: owner.email,
      subject: "Your Holistic Business Solutions portal is ready",
      reply_to: "support@holisticbusinesssolution.com"
    ) do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end

  private

  def direct_mail(to:, subject:, body_html:, body_text:, placeholders: {}, reply_to: nil)
    html = interpolate(body_html, placeholders)
    text = interpolate(body_text, placeholders)
    mail(to: to, subject: subject, reply_to: reply_to) do |format|
      format.html { render html: html.html_safe }
      format.text { render plain: text }
    end
  end
end
