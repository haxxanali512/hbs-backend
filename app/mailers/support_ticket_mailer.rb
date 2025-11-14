class SupportTicketMailer < ApplicationMailer
  default from: "support@hbsdata.com"

  def acknowledgement(ticket)
    @ticket = ticket
    mail(
      to: ticket.created_by_user.email,
      subject: "We received your support ticket ##{ticket.id}"
    )
  end

  def ticket_assigned(ticket, actor = nil)
    @ticket = ticket
    @actor = actor
    return unless ticket.assigned_to_user&.email

    mail(
      to: ticket.assigned_to_user.email,
      subject: "New support ticket assigned: ##{ticket.id}"
    )
  end

  def status_changed(ticket, actor = nil)
    @ticket = ticket
    @actor = actor
    mail(
      to: ticket.created_by_user.email,
      subject: "Ticket ##{ticket.id} status updated to #{ticket.status.humanize}"
    )
  end

  def priority_changed(ticket, actor = nil, reason: nil)
    @ticket = ticket
    @actor = actor
    @reason = reason

    recipients = [ ticket.created_by_user.email, ticket.assigned_to_user&.email ].compact
    return if recipients.empty?

    mail(
      to: recipients,
      subject: "Ticket ##{ticket.id} priority escalated to #{ticket.priority.humanize}"
    )
  end

  def comment_added(ticket, comment)
    @ticket = ticket
    @comment = comment

    recipients =
      if comment.internal?
        ticket.assigned_to_user&.email
      elsif comment.author_user_id == ticket.created_by_user_id
        ticket.assigned_to_user&.email
      else
        ticket.created_by_user.email
      end

    return if recipients.blank?

    mail(
      to: recipients,
      subject: "New comment on ticket ##{ticket.id}"
    )
  end

  def closed(ticket, actor = nil)
    @ticket = ticket
    @actor = actor
    mail(
      to: ticket.created_by_user.email,
      subject: "Ticket ##{ticket.id} closed"
    )
  end

  def reopened(ticket, actor = nil)
    @ticket = ticket
    @actor = actor
    mail(
      to: ticket.created_by_user.email,
      subject: "Ticket ##{ticket.id} reopened"
    )
  end

  def sla_breach(ticket, breach_type)
    @ticket = ticket
    @breach_type = breach_type

    hbs_recipients = User.joins(:role)
                         .where(roles: { scope: Role.scopes[:global] })
                         .pluck(:email)

    recipients = (hbs_recipients + Array(ticket.assigned_to_user&.email)).compact.uniq
    return if recipients.empty?

    mail(
      to: recipients,
      subject: "SLA breach detected on ticket ##{ticket.id}"
    )
  end
end
