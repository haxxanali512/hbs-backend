class ClaimLine < ApplicationRecord
  belongs_to :claim
  belongs_to :procedure_code
  has_many :payment_applications, dependent: :nullify

  enum status: {
    generated: "generated",
    locked_on_submission: "locked_on_submission",
    adjudicated: "adjudicated"
  }, _prefix: true

  # Validations
  validates :claim, presence: { message: "CL_LINE_CLAIM_REQUIRED" }
  validates :procedure_code, presence: { message: "CL_LINE_PROC_REQUIRED" }

  validates :units,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, message: "CL_LINE_UNITS_INVALID" }

  validates :amount_billed,
            numericality: { greater_than_or_equal_to: 0, message: "CL_LINE_AMOUNT_INVALID" }

  validate :validate_modifiers
  validate :validate_place_of_service_matches_claim
  validate :validate_dx_pointers_policy
  validate :validate_immutable_billed_fields_post_submission, on: :update

  before_validation :default_place_of_service_from_claim

  # Billed fields are immutable after submission lock
  IMMUTABLE_BILLED_FIELDS = %w[procedure_code_id units amount_billed modifiers dx_pointers_numeric place_of_service_code].freeze

  def billed_fields_changed?
    (changed & IMMUTABLE_BILLED_FIELDS).any?
  end

  private

  def default_place_of_service_from_claim
    self.place_of_service_code ||= claim&.place_of_service_code
  end

  def validate_modifiers
    return if modifiers.blank?

    # maximum of 4, unique per line
    if modifiers.length > 4
      errors.add(:modifiers, "CL_LINE_MODIFIER_DUPLICATE") # use duplicate code as a generic signal; UI copy can clarify
    end

    if modifiers.uniq.length != modifiers.length
      errors.add(:modifiers, "CL_LINE_MODIFIER_DUPLICATE")
    end
  end

  def validate_place_of_service_matches_claim
    return if claim.blank? || place_of_service_code.blank?

    unless place_of_service_code == claim.place_of_service_code
      errors.add(:place_of_service_code, "POS_MISMATCH_WITH_HEADER")
    end
  end

  def validate_dx_pointers_policy
    return if dx_pointers_numeric.blank?

    # Values must be integers between 1 and 4
    unless dx_pointers_numeric.all? { |v| v.is_a?(Integer) && v >= 1 && v <= 4 }
      errors.add(:dx_pointers_numeric, "DX_POINTER_INVALID_VALUE")
      return
    end

    # Must be unique, contiguous starting at 1, no gaps
    sorted = dx_pointers_numeric.sort
    if sorted.uniq.length != sorted.length
      errors.add(:dx_pointers_numeric, "DX_POINTER_INVALID_VALUE")
      return
    end

    expected = (1..sorted.length).to_a
    unless sorted == expected
      errors.add(:dx_pointers_numeric, "DX_POINTER_GAPS_NOT_ALLOWED")
      return
    end

    # Length cannot exceed min(4, encounter diagnosis count)
    encounter_dx_count = claim&.encounter&.encounter_diagnosis_codes&.count || 0
    max_allowed = [ 4, encounter_dx_count ].min
    if sorted.length > max_allowed
      errors.add(:dx_pointers_numeric, "DX_POINTER_COUNT_EXCEEDS_DIAGNOSES")
    end
  end

  def validate_immutable_billed_fields_post_submission
    return unless billed_fields_changed?

    if claim&.submitted? || status_locked_on_submission? || status_adjudicated?
      errors.add(:base, "CL_LINE_IMMUTABLE_POST_SUBMIT")
    end
  end
end

class ClaimLine < ApplicationRecord
end
