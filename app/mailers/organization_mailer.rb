class OrganizationMailer < ApplicationMailer
  helper :application
  include Devise::Controllers::UrlHelpers
  default from: "support@holisticbusinesssolution.com"

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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com"
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
      reply_to: "support@holisticbusinesssolution.com",
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
      reply_to: "support@holisticbusinesssolution.com",
      default_subject: "Plan Enrollment Step Completed: #{step_type.humanize}",
      default_body_html: "<p>Hello #{owner&.first_name || 'there'},</p><p>The enrollment step '#{step_type.humanize}' has been completed for plan '#{plan.insurance_plan&.name || 'Plan'}' in your organization #{organization.name}.</p><p>You can view your activation progress in your organization portal.</p>"
    )
  end

  # Custom first-time access email for org owners when an org is activated directly.
  # This email includes:
  # - A one-time invitation link to set password
  # - The tenant portal URL (with subdomain)
  # - Basic guidance on how to access the portal
  def owner_activation_invite(organization, invitation_token)
    owner = organization.owner
    return if owner.nil?

    # Build tenant host for the org (same logic as elsewhere for subdomain URLs)
    if Rails.env.development?
      tenant_host = "#{organization.subdomain}.localhost"
      protocol = "http"
      port = ActionMailer::Base.default_url_options[:port] || 3000
    else
      tenant_host = "#{organization.subdomain}.holisticbusinesssolution.com"
      protocol = "https"
      port = nil
    end

    url_opts = { host: tenant_host, protocol: protocol }
    url_opts[:port] = port if port.present?

    # Build the invitation acceptance URL on the tenant subdomain
    # This ensures the user accepts the invitation and sets password on their org's portal
    begin
      invite_link = accept_user_invitation_url(url_opts.merge(invitation_token: invitation_token))
    rescue => e
      Rails.logger.error "[OrganizationMailer] Failed to build invite URL: #{e.message}"
      # Fallback: build URL manually if helper fails
      base_url = port.present? ? "#{protocol}://#{tenant_host}:#{port}" : "#{protocol}://#{tenant_host}"
      invite_link = "#{base_url}/users/invitation/accept?invitation_token=#{invitation_token}"
    end
    portal_url =
      if port.present?
        "#{protocol}://#{tenant_host}:#{port}"
      else
        "#{protocol}://#{tenant_host}"
      end

    # Build subdomain display string (same logic as ApplicationHelper)
    subdomain_display = if Rails.env.development?
      "#{organization.subdomain}.localhost:3000"
    else
      "#{organization.subdomain}.holisticbusinesssolution.net"
    end

    placeholders = {
      owner_first_name: owner.first_name.presence || owner.email,
      organization_name: organization.name,
      invite_link: invite_link,
      portal_url: portal_url,
      subdomain_display: subdomain_display
    }

    default_subject = "Your Holistic Business Solutions portal is ready"

    default_body_html = <<~HTML
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

    default_body_text = <<~TEXT
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

    mail = send_email_via_service(
      template_key: "organization.owner_activation_invite",
      to: owner.email,
      placeholders: placeholders,
      reply_to: "support@holisticbusinesssolution.com",
      default_subject: default_subject,
      default_body_html: default_body_html,
      default_body_text: default_body_text
    )
    mail.deliver_now
  end
end
