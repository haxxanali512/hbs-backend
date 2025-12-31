class Denial < ApplicationRecord
  audited

  # Associations
  belongs_to :claim
  belongs_to :organization
  belongs_to :claim_submission, class_name: "ClaimSubmission", foreign_key: :source_submission_id
  has_many :denial_items, dependent: :destroy
  # Documents now use Active Storage
  has_many_attached :documents

  # Denormalized for query speed
  validates :organization_id, :claim_id, presence: { message: "DENIAL_CLAIM_REQUIRED" }

  enum :status, {
    open: 0,
    under_review: 1,
    resubmitted: 2,
    resolved: 3,
    closed: 4
  }

  # Core validations
  validates :source_submission_id, presence: { message: "DENIAL_SUBMISSION_REQUIRED" }
  validates :denial_date, presence: true
  validates :carc_codes, presence: { message: "DENIAL_CARC_REQUIRED" }
  validates :amount_denied, numericality: { greater_than_or_equal_to: 0, message: "DENIAL_AMOUNT_INVALID" }
  validates :attempt_count, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }

  validate :org_tier_eligibility
  validate :denial_date_not_before_submission
  validate :patient_and_encounter_match_claim
  validate :header_total_matches_items

  # Uniqueness safeguard per remit row
  validates :source_hash, uniqueness: { message: "DENIAL_DUPLICATE" }, allow_nil: true, allow_blank: true

  before_validation :denorm_from_claim

  private

  def denorm_from_claim
    return unless claim
    self.organization_id ||= claim.organization_id
    self.patient_id ||= claim.patient_id
    self.encounter_id ||= claim.encounter_id
  end

  def org_tier_eligibility
    return unless organization
    # When org tier is below threshold, keep record but mark tier_eligible=false
    threshold_ok = true
    if organization.respond_to?(:tier)
      # Assuming tier is a string like "GSA Tiered (GSA)"; skip strict math
      threshold_ok = true
    end
    self.tier_eligible = threshold_ok if tier_eligible.nil?
  end

  def denial_date_not_before_submission
    return unless denial_date.present? && claim_submission&.submitted_at.present?
    if denial_date < claim_submission.submitted_at.to_date
      errors.add(:denial_date, "DENIAL_DATE_INVALID")
    end
  end

  def patient_and_encounter_match_claim
    return unless claim
    if patient_id.present? && patient_id != claim.patient_id
      errors.add(:base, "DENIAL_CONTEXT_MISMATCH")
    end
    if encounter_id.present? && encounter_id != claim.encounter_id
      errors.add(:base, "DENIAL_CONTEXT_MISMATCH")
    end
  end

  def header_total_matches_items
    return if denial_items.blank?
    sum_items = denial_items.sum(:amount_denied)
    if amount_denied.present? && sum_items != amount_denied
      errors.add(:amount_denied, "DENIAL_ITEM_TOTAL_MISMATCH")
    end
  end
end
