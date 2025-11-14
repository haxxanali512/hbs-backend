class Admin::SupportTicketsController < Admin::BaseController
  before_action :set_support_ticket, only: [ :show, :update, :close, :reopen, :add_internal_note, :attach_document ]

  def index
    tickets = SupportTicket.kept.includes(:organization, :created_by_user, :assigned_to_user).order(created_at: :desc)
    tickets = tickets.where(status: params[:status]) if params[:status].present?
    tickets = tickets.where(priority: params[:priority]) if params[:priority].present?
    tickets = tickets.where(category: params[:category]) if params[:category].present?
    tickets = tickets.where(organization_id: params[:organization_id]) if params[:organization_id].present?

    @pagy, @support_tickets = pagy(tickets)

    # For shared filters partial
    @use_status_for_action_type = true
    @status_options = SupportTicket.statuses.keys.map { |k| [ k.humanize, k ] }
    # Get all organizations that have support tickets (before filtering)
    base_tickets = SupportTicket.kept.reorder(nil)
    organization_ids = base_tickets.distinct.pluck(:organization_id).compact
    @organization_options = Organization.where(id: organization_ids).order(:name)
    @priority_options = SupportTicket.priorities.keys.map { |k| [ k.humanize, k ] }
    @category_options = SupportTicket.categories.keys.map { |k| [ k.humanize, k ] }
  end

  def show
    @comment = SupportTicketComment.new
    @comments = @support_ticket.comments.chronological.includes(:author_user)
    @documents = @support_ticket.documents.includes(:document_attachments, :created_by).order(created_at: :desc)
  end

  def update
    ticket_params = support_ticket_params

    SupportTicket.transaction do
      if ticket_params[:assigned_to_user_id].present?
        assign_ticket(@support_ticket, ticket_params[:assigned_to_user_id])
      end

      if ticket_params[:priority].present? && ticket_params[:priority] != @support_ticket.priority
        previous_priority = @support_ticket.priority
        @support_ticket.update!(priority: ticket_params[:priority])
        SupportTicketEventPublisher.priority_changed(@support_ticket, current_user, from: previous_priority, to: @support_ticket.priority)
        SupportTicketMailer.priority_changed(@support_ticket, current_user).deliver_later
      end

      if ticket_params[:status].present? && ticket_params[:status] != @support_ticket.status
        @support_ticket.transition_status!(ticket_params[:status], actor: current_user)
      end

      if ticket_params.key?(:linked_resource_type) || ticket_params.key?(:linked_resource_id)
        @support_ticket.update!(linked_resource_type: ticket_params[:linked_resource_type],
                                linked_resource_id: ticket_params[:linked_resource_id])
      end
    end

    redirect_to admin_support_ticket_path(@support_ticket), notice: "Ticket updated."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_support_ticket_path(@support_ticket), alert: e.record.errors.full_messages.to_sentence
  end

  def close
    @support_ticket.close!(actor: current_user)
    redirect_to admin_support_ticket_path(@support_ticket), notice: "Ticket closed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_support_ticket_path(@support_ticket), alert: e.record.errors.full_messages.to_sentence
  end

  def reopen
    @support_ticket.reopen!(actor: current_user)
    redirect_to admin_support_ticket_path(@support_ticket), notice: "Ticket reopened."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_support_ticket_path(@support_ticket), alert: e.record.errors.full_messages.to_sentence
  end

  def add_internal_note
    @support_ticket.append_internal_note!(body: params[:note][:body], author: current_user)
    redirect_to admin_support_ticket_path(@support_ticket), notice: "Internal note added."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_support_ticket_path(@support_ticket), alert: e.record.errors.full_messages.to_sentence
  end

  def attach_document
    result = DocumentUploadService.new(
      documentable: @support_ticket,
      uploaded_by: current_user,
      organization: @support_ticket.organization,
      params: {
        file: params.dig(:document, :file),
        title: params.dig(:document, :title),
        document_type: params.dig(:document, :document_type) || "support_ticket_attachment",
        description: params.dig(:document, :description)
      }
    ).call

    if result[:success]
      redirect_to admin_support_ticket_path(@support_ticket), notice: "Document attached successfully."
    else
      redirect_to admin_support_ticket_path(@support_ticket), alert: "Failed to attach document: #{result[:error]}"
    end
  end

  private

  def set_support_ticket
    @support_ticket = SupportTicket.find(params[:id])
  end

  def assign_ticket(ticket, assignee_id)
    assignee = User.find(assignee_id)
    ticket.update!(assigned_to_user: assignee)
    SupportTicketEventPublisher.ticket_assigned(ticket, current_user)
    SupportTicketMailer.ticket_assigned(ticket, current_user).deliver_later
  end

  def support_ticket_params
    params.require(:support_ticket).permit(
      :assigned_to_user_id,
      :priority,
      :status,
      :linked_resource_type,
      :linked_resource_id
    )
  end
end
