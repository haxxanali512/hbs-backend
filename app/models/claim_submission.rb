class ClaimSubmission < ApplicationRecord
  belongs_to :claim
  belongs_to :organization, optional: true
  belongs_to :patient, optional: true
  belongs_to :payer, optional: true
  belongs_to :prior_submission, class_name: "ClaimSubmission", optional: true
  has_many :resubmissions, class_name: "ClaimSubmission", foreign_key: :prior_submission_id, dependent: :nullify

  enum :submission_method, {
    api: "api",
    sftp: "sftp",
    manual_upload: "manual_upload"
  }

  enum :ack_status, {
    pending: "pending",
    rejected: "rejected",
    error: "error"
  }

  enum :status, {
    draft: 0,
    submitted: 1,
    rejected_state: 2,
    error_state: 3,
    voided: 4,
    replaced: 5
  }

  # Resubmission reason per X12 (7=Replacement, 8=Void). Store as string to match spec.
  RESUBMISSION_REASONS = [ "7", "8" ].freeze

  # Defaults
  before_validation :set_denormalized_fields
  before_validation :set_default_statuses

  # Validations
  validates :claim_id, presence: { message: "CLAIM_SUB_REQUIRED" }
  validates :organization_id, presence: { message: "ORG_REQUIRED" }
  validates :submission_method, inclusion: { in: submission_methods.keys, message: "SUBMISSION_METHOD_INVALID" }
  validates :ack_status, inclusion: { in: ack_statuses.keys }
  validates :external_submission_key, presence: true, uniqueness: { scope: :claim_id, message: "EXTERNAL_KEY_DUPLICATE" }
  validates :submitted_at, presence: true, if: :submitted_or_after?
  validate :submitted_at_ordering
  validate :claim_must_be_validated
  validate :organization_active_and_not_delinquent

  # Scopes
  scope :latest_first, -> { order(submitted_at: :desc, created_at: :desc) }

  def submitted_or_after?
    submitted? || rejected_state? || error_state? || voided? || replaced?
  end

  private

  def set_denormalized_fields
    return unless claim
    self.organization_id ||= claim.organization_id
    self.patient_id ||= claim.patient_id
    # payer_id is not present on Claim yet; will be set by caller if available
  end

  def set_default_statuses
    self.status ||= :draft
    self.submission_method ||= :api
    self.ack_status ||= :pending
  end

  def submitted_at_ordering
    return unless submitted_at.present? && claim
    prior = claim.claim_submissions.where.not(id: id).where.not(submitted_at: nil).maximum(:submitted_at)
    if prior && submitted_at < prior
      errors.add(:submitted_at, "SUBMISSION_TIMESTAMP_ORDER")
    end
  end

  def claim_must_be_validated
    return unless submitted_or_after? && claim
    unless claim.validated? || claim.submitted? || claim.accepted?
      errors.add(:claim_id, "CLAIM_NOT_VALIDATED")
    end
  end

  def organization_active_and_not_delinquent
    return unless organization
    unless organization.activated?
      errors.add(:organization_id, "ORG_NOT_ACTIVE")
    end
    if organization.organization_billing&.billing_status == "cancelled"
      errors.add(:organization_id, "ORG_BILLING_DELINQUENT")
    end
  end
end
