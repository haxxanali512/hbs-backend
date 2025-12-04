class Tenant::EncounterCommentsController < Tenant::BaseController
  before_action :set_encounter

  def index
    @comments = @encounter.encounter_comments
      .shared
      .where(redacted: false)
      .includes(:author)
      .order(created_at: :asc)

    # Mark as seen
    if current_user
      EncounterCommentSeen.mark_as_seen(@encounter.id, current_user.id)
    end
  end

  def create
    @comment = @encounter.encounter_comments.build(encounter_comment_params)
    @comment.author = current_user
    @comment.visibility = :shared_with_client

    if @comment.save
      redirect_to tenant_encounter_path(@encounter), notice: "Comment added successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Cannot add comment: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_encounter
    @encounter = @current_organization.encounters.find(params[:encounter_id])
  end

  def set_encounter_comment
    @encounter_comment = @encounter.encounter_comments.find(params[:id])
  end

  def encounter_comment_params
    params.require(:encounter_comment).permit(:body_text)
  end
end
