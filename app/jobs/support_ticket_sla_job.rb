class SupportTicketSlaJob < ApplicationJob
  queue_as :default

  def perform(ticket_id, sla_type)
    ticket = SupportTicket.find_by(id: ticket_id)
    return unless ticket

    case sla_type.to_s
    when "first_response"
      return unless ticket.open?
    when "resolution"
      return if ticket.resolved? || ticket.closed?
    else
      return
    end

    return if ticket.tasks.open_tasks.exists?(task_type: sla_type)

    ticket.breach!(sla_type)
  end
end
