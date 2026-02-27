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
    existing_comments = @encounter.encounter_comments.where.not(id: nil)
    hbs_initiated = existing_comments.any? { |c| c.actor_type.to_s.in?([ "hbs_admin", "hbs_user", "system" ]) }

    unless hbs_initiated
      redirect_to tenant_encounter_path(@encounter), alert: "HBS must start this thread before clients can comment."
      return
    end

    files = Array(params.dig(:encounter_comment, :files)).compact.select { |f| f.respond_to?(:original_filename) && f.present? }
    body_text = encounter_comment_params[:body_text].to_s.strip
    if body_text.blank? && files.empty?
      redirect_to tenant_encounter_path(@encounter), alert: "Add a message and/or attach at least one file."
      return
    end
    body_text = "File uploaded" if body_text.blank? && files.any?

    comment_attrs = encounter_comment_params.except(:files).merge(body_text: body_text)
    @comment = @encounter.encounter_comments.build(comment_attrs)
    @comment.author = current_user
    @comment.visibility = :shared_with_client

    # Tenants may only update status (e.g. to info_request_answered) when current status is Information Request
    if @comment.status_transition.present? && @comment.status_transition != "no_change"
      unless @encounter.shared_status == "additional_info_requested"
        @comment.status_transition = "no_change"
      end
    end

    if @comment.save
      files.each do |file|
        att = @comment.encounter_comment_attachments.build
        att.file.attach(file)
        unless att.save
          redirect_to tenant_encounter_path(@encounter), alert: "Comment saved but attachment failed: #{att.errors.full_messages.join(', ')}"
          return
        end
      end
      notice = files.any? ? "Comment and #{files.size} file(s) added successfully." : "Comment added successfully."
      redirect_to tenant_encounter_path(@encounter), notice: notice
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
    params.require(:encounter_comment).permit(:body_text, :status_transition, files: [])
  end
end
