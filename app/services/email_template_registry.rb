class EmailTemplateRegistry
  Template = Struct.new(
    :key,
    :name,
    :description,
    :default_subject,
    :default_body_html,
    :default_body_text,
    :default_locale,
    keyword_init: true
  )

  def self.all
    registry.values
  end

  def self.fetch(key)
    registry[key.to_s]
  end

  def self.registry
    @registry ||= build_registry.freeze
  end

  def self.build_registry
    templates = []

    templates << Template.new(
      key: "organization.organization_created",
      name: "Organization Created",
      description: "Sent to the organization owner when a new organization is created.",
      default_subject: "Welcome! Your organization '{{organization_name}}' has been created",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Your organization <strong>{{organization_name}}</strong> has been created in the HBS platform.</p>
        <p>Sign in to complete the remaining onboarding steps.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "organization.billing_setup_required",
      name: "Billing Setup Required",
      description: "Notifies the owner that billing setup is needed.",
      default_subject: "Next Step: Complete Billing Setup for {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Please complete the billing setup for <strong>{{organization_name}}</strong> to keep things moving.</p>
        <p>You can finish billing setup from your organization dashboard.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "organization.compliance_setup_required",
      name: "Compliance Setup Required",
      description: "Alerts the owner that compliance setup is pending.",
      default_subject: "Next Step: Complete Compliance Setup for {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>The next onboarding step for <strong>{{organization_name}}</strong> is compliance setup.</p>
        <p>Please review and complete the required compliance information.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "organization.document_signing_required",
      name: "Document Signing Required",
      description: "Notifies the owner to sign documents.",
      default_subject: "Next Step: Sign documents for {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Document signing is ready for <strong>{{organization_name}}</strong>.</p>
        <p>Please review and sign the outstanding documents to continue.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "organization.organization_activated",
      name: "Organization Activated",
      description: "Sent when an organization completes activation.",
      default_subject: "🎉 {{organization_name}} is now fully activated",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Great news—<strong>{{organization_name}}</strong> is now fully activated.</p>
        <p>You can start working in the platform immediately.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "organization.activation_completed",
      name: "Activation Completed",
      description: "Final message in activation journey.",
      default_subject: "✅ Activation complete - {{organization_name}} is ready to use",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>The activation journey for <strong>{{organization_name}}</strong> is complete.</p>
        <p>Invite your team, configure workflows, and start working with HBS.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "billing.manual_payment_request",
      name: "Manual Payment Request",
      description: "Notifies super admins about manual payment requests.",
      default_subject: "Manual Payment Request - {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello team,</p>
        <p>{{owner_name}} submitted a manual payment request for <strong>{{organization_name}}</strong>.</p>
        <p>Billing period: {{billing_period}}<br/>Amount requested: {{amount_requested}}</p>
        <p>Please review the request in the admin portal.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "billing.manual_payment_approved",
      name: "Manual Payment Approved",
      description: "Sent to the owner when a manual payment is approved.",
      default_subject: "Payment approved - {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Your manual payment for <strong>{{organization_name}}</strong> was approved.</p>
        <p>No additional action is required.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "billing.manual_payment_rejected",
      name: "Manual Payment Rejected",
      description: "Notifies the owner when a manual payment is rejected.",
      default_subject: "Payment rejected - {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>The manual payment for <strong>{{organization_name}}</strong> could not be approved.</p>
        <p>Please review the billing details and resubmit.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "billing.billing_setup_completed",
      name: "Billing Setup Completed",
      description: "Sent when billing setup is completed.",
      default_subject: "Billing setup complete - {{organization_name}}",
      default_body_html: <<~HTML,
        <p>Hello {{owner_first_name}},</p>
        <p>Billing setup for <strong>{{organization_name}}</strong> is complete.</p>
        <p>You can now manage payments directly from the platform.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.acknowledgement",
      name: "Support Ticket Acknowledgement",
      description: "Confirms receipt of a support ticket to the requester.",
      default_subject: "We received your support ticket {{ticket_id}}",
      default_body_html: <<~HTML,
        <p>Hello {{requester_name}},</p>
        <p>Thanks for contacting support. Your ticket <strong>{{ticket_id}}</strong> ({{ticket_subject}}) is now in our queue.</p>
        <p>We'll let you know as soon as we have an update.</p>
        <p>Thanks,<br/>HBS Support</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.ticket_assigned",
      name: "Support Ticket Assigned",
      description: "Sends an alert to the assignee when a ticket is assigned.",
      default_subject: "New support ticket assigned: {{ticket_id}}",
      default_body_html: <<~HTML,
        <p>Hello {{assignee_name}},</p>
        <p>Ticket <strong>{{ticket_id}}</strong> ({{ticket_subject}}) has been assigned to you.</p>
        <p>Please review the ticket details and follow up with the requester.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.status_changed",
      name: "Support Ticket Status Changed",
      description: "Notifies the requester when ticket status changes.",
      default_subject: "Ticket {{ticket_id}} status updated to {{ticket_status}}",
      default_body_html: <<~HTML,
        <p>Hello {{requester_name}},</p>
        <p>Your ticket <strong>{{ticket_id}}</strong> was updated to <strong>{{ticket_status}}</strong>.</p>
        <p>{{status_actor_line}}</p>
        <p>Thanks,<br/>HBS Support</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.priority_changed",
      name: "Support Ticket Priority Changed",
      description: "Notifies participants when ticket priority changes.",
      default_subject: "Ticket {{ticket_id}} priority escalated to {{ticket_priority}}",
      default_body_html: <<~HTML,
        <p>Hello,</p>
        <p>Ticket <strong>{{ticket_id}}</strong> priority changed to <strong>{{ticket_priority}}</strong>.</p>
        <p>{{status_actor_line}}</p>
        <p>{{priority_reason_line}}</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.comment_added",
      name: "Support Ticket Comment Added",
      description: "Sent when a new comment is added to a ticket.",
      default_subject: "New comment on ticket {{ticket_id}}",
      default_body_html: <<~HTML,
        <p>Hello,</p>
        <p>A new comment was posted on ticket <strong>{{ticket_id}}</strong>.</p>
        <blockquote>{{comment_body}}</blockquote>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.closed",
      name: "Support Ticket Closed",
      description: "Notifies the requester that the ticket was closed.",
      default_subject: "Ticket {{ticket_id}} closed",
      default_body_html: <<~HTML,
        <p>Hello {{requester_name}},</p>
        <p>We closed ticket <strong>{{ticket_id}}</strong>.</p>
        <p>{{status_actor_line}}</p>
        <p>If the issue is not resolved, you can reply to reopen it.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.reopened",
      name: "Support Ticket Reopened",
      description: "Alerts the requester that the ticket was reopened.",
      default_subject: "Ticket {{ticket_id}} reopened",
      default_body_html: <<~HTML,
        <p>Hello {{requester_name}},</p>
        <p>Ticket <strong>{{ticket_id}}</strong> was reopened.</p>
        <p>{{status_actor_line}}</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "support_ticket.sla_breach",
      name: "Support Ticket SLA Breach",
      description: "Notifies admins when an SLA is breached.",
      default_subject: "SLA breach detected on ticket {{ticket_id}}",
      default_body_html: <<~HTML,
        <p>Hello,</p>
        <p>Ticket <strong>{{ticket_id}}</strong> breached the <strong>{{sla_breach_type}}</strong> SLA.</p>
        <p>Please review and take action.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "devise.invitation_instructions",
      name: "User Invitation Instructions",
      description: "Sent to users when they are invited to the platform.",
      default_subject: "You're invited to Holistic Business Solutions",
      default_body_html: <<~HTML,
        <p>Hello {{user_full_name}},</p>
        <p>You have been invited to join Holistic Business Solutions.</p>
        <p><a href="{{invitation_url}}">Click here</a> to accept your invitation and set up your account.</p>
        <p>Thanks,<br/>Holistic Business Solutions</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "devise.reset_password_instructions",
      name: "Reset Password Instructions",
      description: "Sent when a user requests to reset their password.",
      default_subject: "Reset your Holistic Business Solutions password",
      default_body_html: <<~HTML,
        <p>Hello {{user_full_name}},</p>
        <p>We received a request to reset the password for your account.</p>
        <p><a href="{{reset_password_url}}">Click here to choose a new password.</a></p>
        <p>If you did not request this change, please ignore this email.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "devise.unlock_instructions",
      name: "Unlock Instructions",
      description: "Sent when an account is locked and needs to be unlocked.",
      default_subject: "Unlock your Holistic Business Solutions account",
      default_body_html: <<~HTML,
        <p>Hello {{user_full_name}},</p>
        <p>Your account was locked after too many unsuccessful sign-in attempts.</p>
        <p><a href="{{unlock_account_url}}">Click here</a> to unlock your account.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "devise.email_changed",
      name: "Email Changed Notification",
      description: "Confirms to the user that their email was changed.",
      default_subject: "Your Holistic Business Solutions email was updated",
      default_body_html: <<~HTML,
        <p>Hello {{user_full_name}},</p>
        <p>This is a confirmation that your account email is now <strong>{{new_email}}</strong>.</p>
        <p>If you didn't make this change, please contact support immediately.</p>
      HTML
      default_locale: "en"
    )

    templates << Template.new(
      key: "devise.password_change",
      name: "Password Changed Notification",
      description: "Sent after a user successfully changes their password.",
      default_subject: "Your Holistic Business Solutions password was changed",
      default_body_html: <<~HTML,
        <p>Hello {{user_full_name}},</p>
        <p>This is a confirmation that your password was changed.</p>
        <p>If you did not perform this action, please reset your password immediately.</p>
      HTML
      default_locale: "en"
    )

    templates.each_with_object({}) do |template, hash|
      hash[template.key] = template
    end
  end
end
