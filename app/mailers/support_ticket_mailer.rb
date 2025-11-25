class SupportTicketMailer < ApplicationMailer
  default from: "support@hbsdata.com"

  def acknowledgement(ticket)
    send_ticket_email(
      ticket: ticket,
      template_key: "support_ticket.acknowledgement"
    )
  end

  def ticket_assigned(ticket, actor = nil)
    return unless ticket.assigned_to_user&.email

    send_ticket_email(
      ticket: ticket,
      template_key: "support_ticket.ticket_assigned",
      to_override: ticket.assigned_to_user.email
    )
  end

  def status_changed(ticket, actor = nil)
    send_ticket_email(
      ticket: ticket,
      actor: actor,
      template_key: "support_ticket.status_changed",
    )
  end

  def priority_changed(ticket, actor = nil, reason: nil)
    recipients = [ ticket.created_by_user.email, ticket.assigned_to_user&.email ].compact
    return if recipients.empty?

    send_ticket_email(
      ticket: ticket,
      actor: actor,
      template_key: "support_ticket.priority_changed",
      to_override: recipients,
      extra_placeholders: { priority_reason: reason }
    )
  end

  def comment_added(ticket, comment)
    recipients =
      if comment.internal?
        ticket.assigned_to_user&.email
      elsif comment.author_user_id == ticket.created_by_user_id
        ticket.assigned_to_user&.email
      else
        ticket.created_by_user.email
      end

    return if recipients.blank?

    send_ticket_email(
      ticket: ticket,
      template_key: "support_ticket.comment_added",
      to_override: recipients,
      extra_placeholders: {
        comment_body: comment.body,
        comment_author: comment.author_user&.full_name || comment.author_user&.email
      }
    )
  end

  def closed(ticket, actor = nil)
    send_ticket_email(
      ticket: ticket,
      actor: actor,
      template_key: "support_ticket.closed",
    )
  end

  def reopened(ticket, actor = nil)
    send_ticket_email(
      ticket: ticket,
      actor: actor,
      template_key: "support_ticket.reopened",
    )
  end

  def sla_breach(ticket, breach_type)
    hbs_recipients = User.joins(:role)
                         .where(roles: { scope: Role.scopes[:global] })
                         .pluck(:email)

    recipients = (hbs_recipients + Array(ticket.assigned_to_user&.email)).compact.uniq
    return if recipients.empty?

    send_ticket_email(
      ticket: ticket,
      template_key: "support_ticket.sla_breach",
      to_override: recipients,
      extra_placeholders: { sla_breach_type: breach_type.to_s.humanize }
    )
  end

  private

  def send_ticket_email(ticket:, template_key:, actor: nil, to_override: nil, extra_placeholders: {})
    requester = ticket.created_by_user
    assignee = ticket.assigned_to_user
    placeholders = {
      ticket_id: ticket.id,
      ticket_subject: ticket.subject,
      ticket_status: ticket.status.humanize,
      ticket_priority: ticket.priority.humanize,
      requester_name: requester&.full_name || requester&.email,
      assignee_name: assignee&.full_name || assignee&.email,
      organization_name: ticket.organization&.name,
      status_actor_line: actor.present? ? "Updated by #{actor.full_name || actor.email}" : "",
      comment_body: nil,
      priority_reason_line: extra_placeholders[:priority_reason].present? ? "Reason: #{extra_placeholders[:priority_reason]}" : ""
    }.merge(extra_placeholders)

    send_email_via_service(
      template_key: template_key,
      to: to_override || requester.email,
      placeholders: placeholders
    )
  end
end
