class Claim < ApplicationRecord
  audited
  belongs_to :organization
  belongs_to :encounter
  belongs_to :patient
  belongs_to :provider
  belongs_to :specialty
  belongs_to :patient_insurance_coverage, optional: true

  has_many :claim_lines, dependent: :destroy
  has_many :claim_submissions, dependent: :destroy
  has_many :payment_applications, dependent: :restrict_with_error
  has_many :denials, dependent: :restrict_with_error
  accepts_nested_attributes_for :claim_lines, allow_destroy: true

  enum status: {
    generated: 0,
    validated: 1,
    submitted: 2,
    accepted: 3,
    rejected: 4,
    denied: 5,
    applied_to_deductible: 6,
    paid_in_full: 7,
    voided: 8,
    reversed: 9,
    closed: 10
  }

  validates :place_of_service_code, presence: { message: "POS_REQUIRED" }
  validates :encounter_id, uniqueness: { message: "DUPLICATE_CLAIM_FOR_ENCOUNTER" }

  validate :validate_has_lines
  validate :validate_totals_match_rollup
  validate :validate_dx_pointer_policy_claim_wide

  before_validation :rollup_totals
  before_save :update_status_timestamps
  before_create :set_initial_status_and_timestamp

  def rollup_totals
    self.total_units = claim_lines.sum(:units)
    self.total_billed = claim_lines.sum(:amount_billed)
  end

  # Ensure brand-new claims start as generated and capture generated_at
  def set_initial_status_and_timestamp
    self.status = :generated if status.nil?
    self.generated_at ||= Time.current
  end

  # Status transition helpers
  def can_be_voided?
    submitted? || accepted? || rejected? || denied?
  end

  def can_be_reversed?
    paid_in_full? || applied_to_deductible?
  end

  def can_be_closed?
    paid_in_full? || voided? || reversed? || denied?
  end

  def status_badge_color
    case status
    when "generated" then "bg-gray-100 text-gray-800"
    when "validated" then "bg-blue-100 text-blue-800"
    when "submitted" then "bg-yellow-100 text-yellow-800"
    when "accepted" then "bg-green-100 text-green-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "denied" then "bg-red-100 text-red-800"
    when "applied_to_deductible" then "bg-orange-100 text-orange-800"
    when "paid_in_full" then "bg-green-100 text-green-800"
    when "voided" then "bg-gray-100 text-gray-800"
    when "reversed" then "bg-gray-100 text-gray-800"
    when "closed" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def update_status_timestamps
    return unless status_changed?

    case status
    when "generated"
      self.generated_at = Time.current if generated_at.nil?
    when "submitted"
      self.submitted_at = Time.current if submitted_at.nil?
    when "accepted"
      self.accepted_at = Time.current if accepted_at.nil?
    when "paid_in_full", "closed", "voided", "reversed", "denied", "applied_to_deductible"
      self.finalized_at = Time.current if finalized_at.nil?
    end
  end

  private

  def validate_has_lines
    if claim_lines.blank? || claim_lines.empty?
      errors.add(:base, "CLAIM_LINES_REQUIRED")
    end
  end

  def validate_totals_match_rollup
    return if claim_lines.blank?

    computed_units = claim_lines.sum(:units)
    computed_billed = claim_lines.sum(:amount_billed)

    errors.add(:total_units, "CLAIM_UNITS_MISMATCH") if total_units != computed_units
    errors.add(:total_billed, "CLAIM_TOTAL_MISMATCH") if total_billed != computed_billed
  end

  def validate_dx_pointer_policy_claim_wide
    return if claim_lines.blank?

    any_invalid = claim_lines.any? do |line|
      next true if line.dx_pointers_numeric.present? && (!line.valid? && line.errors[:dx_pointers_numeric].present?)

      # Re-run just the pointer validator in case line wasn't validated yet in this lifecycle
      line.errors.delete(:dx_pointers_numeric)
      line.send(:validate_dx_pointers_policy)
      line.errors[:dx_pointers_numeric].present?
    end

    errors.add(:base, "CLAIM_DX_POINTER_POLICY_VIOLATION") if any_invalid
  end
end
