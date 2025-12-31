class Admin::DenialsController < Admin::BaseController
  before_action :set_claim
  before_action :set_denial, only: [ :show, :update, :update_status, :resubmit, :mark_non_correctable, :override_attempt_limit, :attach_doc, :remove_doc ]

  def index
    @denials = @claim.denials.order(denial_date: :desc)
    @pagy, @denials = pagy(@denials, items: 20)
  end

  def show; end

  def create
    @denial = @claim.denials.new(denial_params.merge(organization_id: @claim.organization_id))
    if @denial.save
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Denial created."
    else
      redirect_to admin_claim_path(@claim), alert: @denial.errors.full_messages.join(", ")
    end
  end

  def update
    if @denial.update(denial_params)
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Denial updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_status
    new_status = params[:status]
    if Denial.statuses.key?(new_status)
      @denial.update!(status: new_status)
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Status updated."
    else
      redirect_to admin_claim_denial_path(@claim, @denial), alert: "Invalid status"
    end
  end

  def resubmit
    if @denial.attempt_count >= 2 && !current_user.super_admin?
      return redirect_to admin_claim_denial_path(@claim, @denial), alert: "DENIAL_ATTEMPTS_EXCEEDED"
    end

    @claim.claim_submissions.create!(
      submission_method: :api,
      status: :submitted,
      ack_status: :pending,
      submitted_at: Time.current,
      prior_submission: @denial.claim_submission,
      external_submission_key: SecureRandom.uuid
    )
    @denial.update!(status: :resubmitted, attempt_count: @denial.attempt_count + 1)
    redirect_to admin_claim_denial_path(@claim, @denial), notice: "Resubmission created."
  end

  def mark_non_correctable
    @denial.update!(status: :resolved)
    redirect_to admin_claim_denial_path(@claim, @denial), notice: "Marked non-correctable and resolved."
  end

  def override_attempt_limit
    @denial.update!(attempt_count: 0)
    redirect_to admin_claim_denial_path(@claim, @denial), notice: "Attempt counter reset (override)."
  end

  def attach_doc
    result = DocumentUploadService.new(
      documentable: @denial,
      uploaded_by: current_user,
      organization: @claim.organization,
      params: {
        file: params.dig(:document, :file),
        title: params.dig(:document, :title).presence || "Denial Attachment",
        document_type: params.dig(:document, :document_type).presence || "denial_attachment",
        description: params.dig(:document, :description)
      }
    ).call

    if result[:success]
      redirect_to admin_claim_denial_path(@claim, @denial), notice: "Attachment uploaded."
    else
      redirect_to admin_claim_denial_path(@claim, @denial), alert: "Failed to upload: #{result[:error]}"
    end
  end

  def remove_doc
    attachment = ActiveStorage::Blob.find_signed(params[:attachment_signed_id])
    if attachment
      # Find the attachment record and purge it
      attachment_record = @denial.documents.find_by(blob_id: attachment.id)
      if attachment_record
        attachment_record.purge
        redirect_to admin_claim_denial_path(@claim, @denial), notice: "Attachment removed."
      else
        redirect_to admin_claim_denial_path(@claim, @denial), alert: "Attachment not found for this denial."
      end
    else
      redirect_to admin_claim_denial_path(@claim, @denial), alert: "Invalid attachment ID."
    end
  end

  private

  def set_claim
    @claim = Claim.find(params[:claim_id])
  end

  def set_denial
    @denial = @claim.denials.find(params[:id])
  end

  def denial_params
    params.fetch(:denial, {}).permit(
      :denial_date, :amount_denied, :source_submission_id, :status, :attempt_count, :tier_eligible, :notes_internal, :source_hash,
      carc_codes: [], rarc_codes: []
    )
  end
end
