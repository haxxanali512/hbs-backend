class Tenant::SupportTicketCommentsController < Tenant::BaseController
  before_action :set_support_ticket

  def create
    @comment = @support_ticket.comments.build(
      author_user: current_user,
      visibility: :public,
      body: comment_params[:body]
    )

    if @comment.save
      redirect_to tenant_support_ticket_path(@support_ticket), notice: "Comment added."
    else
      redirect_to tenant_support_ticket_path(@support_ticket),
                  alert: @comment.errors.full_messages.to_sentence
    end
  end

  private

  def set_support_ticket
    @support_ticket = current_organization.support_tickets.find(params[:support_ticket_id])
  end

  def comment_params
    params.require(:support_ticket_comment).permit(:body)
  end
end
