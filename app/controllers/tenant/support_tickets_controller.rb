class Tenant::SupportTicketsController < Tenant::BaseController
  include LinkedResourceOptions
  before_action :set_support_ticket, only: [ :show, :attach_document ]
  before_action :load_linked_resource_options, only: [ :new, :create ]

  def index
    tickets = current_organization.support_tickets
                                  .for_org(current_organization.id)
                                  .order(created_at: :desc)

    tickets = tickets.where(status: params[:status]) if params[:status].present?
    tickets = tickets.where(category: params[:category]) if params[:category].present?
    tickets = tickets.where(priority: params[:priority]) if params[:priority].present?

    @pagy, @support_tickets = pagy(tickets)

    # For shared filters partial
    @use_status_for_action_type = true
    @status_options = SupportTicket.statuses.keys.map { |k| [ k.humanize, k ] }
    @priority_options = SupportTicket.priorities.keys.map { |k| [ k.humanize, k ] }
    @category_options = SupportTicket.categories.keys.map { |k| [ k.humanize, k ] }
  end

  def new
    @support_ticket = current_organization.support_tickets.new
  end

  def create
    @support_ticket = current_organization.support_tickets.new(support_ticket_params)
    @support_ticket.created_by_user = current_user

    if @support_ticket.save
      SupportTicketEventPublisher.ticket_created(@support_ticket)
      SupportTicketMailer.acknowledgement(@support_ticket).deliver_later
      SupportTicketEventPublisher.auto_acknowledged(@support_ticket)
      redirect_to tenant_support_ticket_path(@support_ticket), notice: "Support ticket submitted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def linked_resources
    resource_type = params[:resource_type].to_s
    patient_id = params[:patient_id].presence

    if linked_resource_requires_patient?(resource_type) && patient_id.blank?
      return render json: { success: true, resources: [] }
    end

    resources = linked_resource_options(resource_type, current_organization, patient_id)
    render json: { success: true, resources: resources }
  end

  def show
    @comment = SupportTicketComment.new
    @comments = @support_ticket.comments.chronological
    # Documents now use Active Storage - no need to load separately
    # @documents is now @support_ticket.documents (Active Storage attachments)
  end

  def attach_document
    result = DocumentUploadService.new(
      documentable: @support_ticket,
      uploaded_by: current_user,
      organization: current_organization,
      params: {
        file: params.dig(:document, :file),
        title: params.dig(:document, :title),
        document_type: params.dig(:document, :document_type) || "support_ticket_attachment",
        description: params.dig(:document, :description)
      }
    ).call

    if result[:success]
      redirect_to tenant_support_ticket_path(@support_ticket), notice: "Document attached successfully."
    else
      redirect_to tenant_support_ticket_path(@support_ticket), alert: "Failed to attach document: #{result[:error]}"
    end
  end

  private

  def set_support_ticket
    @support_ticket = current_organization.support_tickets.find(params[:id])
  end

  def load_linked_resource_options
    @patients = current_organization.patients.active.order(:last_name, :first_name)
  end

  def support_ticket_params
    permitted = params.require(:support_ticket).permit(
      :category,
      :sub_category,
      :subject,
      :description,
      :linked_resource_type,
      :linked_resource_id,
      attachments: []
    )

    tokens = params[:support_ticket][:attachment_tokens]
    if tokens.present?
      permitted[:attachments] = tokens.to_s.split(/[\s,]+/).select(&:present?)
    end

    permitted
  end
end
