class SupportTicketEventPublisher
  class << self
    def ticket_created(ticket)
      instrument("support_ticket.created", {
        ticket_id: ticket.id,
        org_id: ticket.organization_id,
        created_by_user_id: ticket.created_by_user_id,
        category: ticket.category
      })
    end

    def auto_acknowledged(ticket)
      instrument("support_ticket.auto_acknowledged", {
        ticket_id: ticket.id,
        sent_at: Time.current
      })
    end

    def ticket_assigned(ticket, actor)
      instrument("support_ticket.assigned", {
        ticket_id: ticket.id,
        assigned_to_user_id: ticket.assigned_to_user_id,
        actor_id: actor&.id
      })
    end

    def status_changed(ticket, actor, from:, to:)
      instrument("support_ticket.status_changed", {
        ticket_id: ticket.id,
        from: from,
        to: to,
        actor_id: actor&.id
      })
    end

    def priority_changed(ticket, actor, from:, to:)
      instrument("support_ticket.priority_changed", {
        ticket_id: ticket.id,
        old_priority: from,
        new_priority: to,
        actor_id: actor&.id
      })
    end

    def comment_added(ticket, comment)
      instrument("support_ticket.comment_added", {
        ticket_id: ticket.id,
        author_id: comment.author_user_id,
        comment_id: comment.id,
        visibility: comment.visibility
      })
    end

    def closed(ticket, actor)
      instrument("support_ticket.closed", {
        ticket_id: ticket.id,
        closed_at: ticket.closed_at,
        actor_id: actor&.id
      })
    end

    def reopened(ticket, actor)
      instrument("support_ticket.reopened", {
        ticket_id: ticket.id,
        actor_id: actor&.id
      })
    end

    def sla_breached(ticket, type)
      instrument("support_ticket.sla_breach", {
        ticket_id: ticket.id,
        type: type,
        breached_at: Time.current
      })
    end

    private

    def instrument(event_name, payload)
      ActiveSupport::Notifications.instrument(event_name, payload)
    end
  end
end
