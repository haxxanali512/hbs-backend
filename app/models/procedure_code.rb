class ProcedureCode < ApplicationRecord
  audited
  include Discard::Model

  has_many :procedure_codes_specialties, dependent: :destroy
  has_many :specialties, through: :procedure_codes_specialties
  has_many :organization_fee_schedule_items, dependent: :restrict_with_error
  has_many :claim_lines, dependent: :restrict_with_error

  enum :code_type, {
    cpt: 0,
    hcpcs: 1,
    icd10: 2,
    custom: 3
  }

  enum :status, {
    active: 0,
    retired: 1
  }

  validates :code, presence: true, uniqueness: { scope: :code_type }
  validates :description, presence: true
  validates :code_type, presence: true
  validates :status, presence: true
  validate :validate_code_uniqueness

  scope :by_code_type, ->(type) { where(code_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: "active") }
  scope :retired, -> { where(status: "retired") }
  scope :search, ->(term) { where("code ILIKE ? OR description ILIKE ?", "%#{term}%", "%#{term}%") }

  def can_be_retired?
    active? && !referenced_by_claims?
  end

  def can_be_activated?
    retired? && !referenced_by_claims?
  end

  def referenced_by_claims?
    # This would check if the code is referenced by any posted claims
    # For now, we'll return false as claims system isn't implemented yet
    false
  end

  def toggle_status!
    if active?
      retire!
    else
      activate!
    end
  end

  def code_with_description
    "#{code} - #{description}"
  end

  def code_type_badge_color
    case code_type
    when "cpt" then "bg-blue-100 text-blue-800"
    when "hcpcs" then "bg-purple-100 text-purple-800"
    when "icd10" then "bg-orange-100 text-orange-800"
    when "custom" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def status_badge_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "retired" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  private

  def retire!
    update!(status: "retired")
  end

  def activate!
    update!(status: "active")
  end

  def validate_code_uniqueness
    result = ProcedureCodeValidationService.validate_code_uniqueness(self)
    unless result[:valid]
      errors.add(:code, result[:error])
    end
  end
end
