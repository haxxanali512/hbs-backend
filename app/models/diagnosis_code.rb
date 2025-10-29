class DiagnosisCode < ApplicationRecord
  include AASM
  audited

  has_many :encounter_diagnosis_codes, dependent: :destroy
  has_many :encounters, through: :encounter_diagnosis_codes

  enum :status, {
    active: 0,
    retired: 1
  }
  aasm column: "status", enum: true do
    state :active, initial: true
    state :retired

    event :retire do
      transitions from: :active, to: :retired,
                  if: :can_be_retired?
    end

    event :activate do
      transitions from: :retired, to: :active,
                  if: :can_be_activated?
    end
  end

  validates :code, presence: true, uniqueness: true
  validates :description, presence: true
  validates :status, presence: true
  validates :code, format: {
    with: /\A[A-Z][0-9]{2}(?:\.[0-9A-Z]{1,4})?\z/,
    message: "DX_CODE_INVALID - Diagnosis code must follow ICD-10-CM format (e.g., M54.5, E11.9, A41.9)"
  }

  scope :active, -> { where(status: :active) }
  scope :retired, -> { where(status: :retired) }
  scope :search, ->(term) {
    where("code ILIKE ? OR description ILIKE ?", "%#{term}%", "%#{term}%")
  }

  def can_be_retired?
    active? && !has_active_encounters?
  end

  def can_be_activated?
    retired?
  end

  def active?
    status == "active"
  end

  def retired?
    status == "retired"
  end

  def has_active_encounters?
    encounters.exists?
  end

  def in_use?
    encounters.exists?
  end

  def code_with_description
    "#{code} - #{description}"
  end

  def status_badge_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "retired" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def self.active_codes
    where(status: :active)
  end

  def self.retired_codes
    where(status: :retired)
  end

  def self.for_encounter
    where(status: :active)
  end
end
