class Admin::EncounterCommentsController < Admin::BaseController
  before_action :set_encounter
  before_action :set_encounter_comment, only: [ :redact ]

  def index
    @comments = @encounter.encounter_comments
      .includes(:author)
      .order(created_at: :asc)

    # Filter by visibility
    @comments = @comments.shared if params[:visibility] == "shared"
    @comments = @comments.internal if params[:visibility] == "internal"

    # Mark as seen
    if current_user
      EncounterCommentSeen.mark_as_seen(@encounter.id, current_user.id)
    end
  end

  def create
    @comment = @encounter.encounter_comments.build(encounter_comment_params)
    @comment.author = current_user

    if @comment.save
      redirect_to admin_encounter_path(@encounter), notice: "Comment added successfully."
    else
      redirect_to admin_encounter_path(@encounter), alert: "Cannot add comment: #{@comment.errors.full_messages.join(', ')}"
    end
  end

  def redact
    unless current_user.can_redact_comment?
      redirect_to admin_encounter_path(@encounter), alert: "Only HBS Admins can redact comments."
      return
    end

    reason = params[:redaction_reason]
    unless reason.present?
      redirect_to admin_encounter_path(@encounter), alert: "Redaction reason is required."
      return
    end

    if @encounter_comment.redact!(reason: reason, redacted_by: current_user)
      redirect_to admin_encounter_path(@encounter), notice: "Comment redacted."
    else
      redirect_to admin_encounter_path(@encounter), alert: "Cannot redact comment: #{@encounter_comment.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_encounter
    @encounter = Encounter.find(params[:encounter_id])
  end

  def set_encounter_comment
    @encounter_comment = @encounter.encounter_comments.find(params[:id])
  end

  def encounter_comment_params
    params.require(:encounter_comment).permit(:body_text, :visibility, :status_transition)
  end
end
