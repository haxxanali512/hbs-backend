class SupportTicketAutoCloseJob < ApplicationJob
  queue_as :default

  def perform(ticket_id, resolved_at)
    ticket = SupportTicket.find_by(id: ticket_id)
    return unless ticket&.resolved?
    resolved_timestamp = Time.zone.parse(resolved_at.to_s)
    return unless ticket.updated_at <= resolved_timestamp + 1.minute

    ticket.update!(status: :closed, closed_at: Time.current)
    SupportTicketEventPublisher.closed(ticket, nil)
    SupportTicketMailer.closed(ticket, nil).deliver_later
  end
end
