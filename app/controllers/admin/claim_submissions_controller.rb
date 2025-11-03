class Admin::ClaimSubmissionsController < Admin::BaseController
  before_action :set_claim
  before_action :set_submission, only: [ :resubmit, :void, :replace ]

  def index
    @submissions = @claim.claim_submissions.latest_first
    @pagy, @submissions = pagy(@submissions, items: 20)
  end

  def create
    sub = @claim.claim_submissions.new(submission_params.merge(status: :submitted, ack_status: :pending, submitted_at: Time.current))
    if sub.save
      redirect_to admin_claim_path(@claim), notice: "Submission created."
    else
      redirect_to admin_claim_path(@claim), alert: sub.errors.full_messages.join(", ")
    end
  end

  def resubmit
    new_sub = @claim.claim_submissions.new(
      submission_method: :api,
      status: :submitted,
      ack_status: :pending,
      resubmission_reason_code: params[:resubmission_reason_code].presence || "7",
      prior_submission: @submission,
      submitted_at: Time.current,
      external_submission_key: SecureRandom.uuid
    )
    if new_sub.save
      redirect_to admin_claim_path(@claim), notice: "Resubmitted."
    else
      redirect_to admin_claim_path(@claim), alert: new_sub.errors.full_messages.join(", ")
    end
  end

  def void
    @submission.update(status: :voided)
    redirect_to admin_claim_path(@claim), notice: "Submission voided."
  end

  def replace
    resubmit
  end

  private

  def set_claim
    @claim = Claim.find(params[:claim_id])
  end

  def set_submission
    @submission = @claim.claim_submissions.find(params[:id])
  end

  def submission_params
    params.fetch(:claim_submission, {}).permit(:submission_method, :external_submission_key, :resubmission_reason_code, :payer_id)
  end
end
