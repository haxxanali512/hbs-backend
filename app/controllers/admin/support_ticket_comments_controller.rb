class Admin::SupportTicketCommentsController < Admin::BaseController
  before_action :set_support_ticket

  def create
    @comment = @support_ticket.comments.build(
      author_user: current_user,
      visibility: comment_params[:visibility] || :internal,
      body: comment_params[:body],
      system_generated: false
    )

    if @comment.save
      redirect_to admin_support_ticket_path(@support_ticket), notice: "Comment posted."
    else
      redirect_to admin_support_ticket_path(@support_ticket), alert: @comment.errors.full_messages.to_sentence
    end
  end

  private

  def set_support_ticket
    @support_ticket = SupportTicket.find(params[:support_ticket_id])
  end

  def comment_params
    params.require(:support_ticket_comment).permit(:body, :visibility)
  end
end
