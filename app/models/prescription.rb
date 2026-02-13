class Prescription < ApplicationRecord
  include Discard::Model

  audited

  # Associations
  belongs_to :organization
  belongs_to :patient
  belongs_to :specialty
  belongs_to :procedure_code, optional: true
  belongs_to :provider, optional: true

  # Many-to-many associations
  has_many :prescription_diagnosis_codes, dependent: :destroy
  has_many :diagnosis_codes, through: :prescription_diagnosis_codes

  # Documents now use Active Storage
  has_many_attached :documents

  # Virtual attributes for form handling
  attr_accessor :diagnosis_code_ids
  attr_accessor :expiration_option, :expiration_duration_value, :expiration_duration_unit, :expiration_date

  # Validations
  validates :expires_on, presence: true
  validates :title, presence: true
  validates :date_written, presence: true
  validates :organization_id, presence: true
  validates :specialty_id, presence: true
  validate :date_written_not_in_future
  validate :expires_after_written
  validate :validate_nyship_expiration_inputs

  # Scopes
  scope :active, -> { kept.where(expired: false, archived: false) }
  scope :expired, -> { kept.where(expired: true) }
  scope :archived, -> { kept.where(archived: true) }
  scope :not_archived, -> { kept.where(archived: false) }
  scope :for_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_specialty, ->(specialty_id) { where(specialty_id: specialty_id) }
  scope :by_procedure_code, ->(procedure_code_id) { where(procedure_code_id: procedure_code_id) }

  # Callbacks
  before_validation :apply_nyship_expiration_rules
  before_save :set_archived_at_if_archived
  after_save :associate_diagnosis_codes

  # Instance Methods
  def archived?
    archived == true
  end

  def archive!
    update!(archived: true, archived_at: Time.current)
  end

  def unarchive!
    update!(archived: false, archived_at: nil)
  end

  def can_be_archived?
    !archived?
  end

  def can_be_unarchived?
    archived?
  end

  private
  def nyship_insurance?
    return false unless patient

    patient.patient_insurance_coverages
           .active_only
           .joins(:insurance_plan)
           .left_joins(insurance_plan: :payer)
           .where("insurance_plans.name ILIKE ? OR payers.name ILIKE ?", "%NYSHIP%", "%NYSHIP%")
           .exists?
  end

  def massage_therapy_code?
    code = procedure_code&.code.to_s
    %w[97124 97140].include?(code)
  end

  def nyship_massage_rule_applicable?
    nyship_insurance? && massage_therapy_code?
  end

  def validate_nyship_expiration_inputs
    case expiration_option.to_s
    when "duration"
      if expiration_duration_value.to_i <= 0
        errors.add(:expires_on, "Duration is required")
      end
    when "date"
      if expiration_date.blank? && expires_on.blank?
        errors.add(:expires_on, "Expiration date is required")
      end
    end
  end

  def apply_nyship_expiration_rules
    return unless date_written.present?

    max_date = date_written + 6.months
    target = max_date

    case expiration_option.to_s
    when "duration"
      value = expiration_duration_value.to_i
      unit = expiration_duration_unit.to_s
      if value.positive?
        duration =
          case unit
          when "days" then value.days
          when "weeks" then value.weeks
          when "months" then value.months
          else value.days
          end
        target = date_written + duration
      end
    when "date"
      # Parse expiration_date string to Date if present
      if expiration_date.present?
        parsed_date = begin
          Date.parse(expiration_date.to_s)
        rescue ArgumentError
          nil
        end
        target = parsed_date if parsed_date.present?
      elsif expires_on.present?
        target = expires_on
      end
      # If neither expiration_date nor expires_on is set, target remains max_date (6 months)
    else
      # "none" option - default to 6 months
      target = max_date
    end

    # For NYSHIP massage prescriptions, cap at 6 months
    if nyship_massage_rule_applicable? && target > max_date
      target = max_date
    end

    self.expires_on = target
  end


  def date_written_not_in_future
    return unless date_written.present?

    if date_written > Date.current
      errors.add(:date_written, "cannot be in the future")
    end
  end

  def expires_after_written
    return unless date_written.present? && expires_on.present?

    if expires_on < date_written
      errors.add(:expires_on, "must be after or equal to date written")
    end
  end

  def set_archived_at_if_archived
    if archived? && archived_at.nil?
      self.archived_at = Time.current
    elsif !archived? && archived_at.present?
      self.archived_at = nil
    end
  end

  def associate_diagnosis_codes
    dx_ids = Array(diagnosis_code_ids).reject(&:blank?)
    return if dx_ids.empty?

    # Clear existing associations
    prescription_diagnosis_codes.destroy_all

    # Create new associations
    dx_ids.each do |dc_id|
      prescription_diagnosis_codes.find_or_create_by(diagnosis_code_id: dc_id.to_i)
    end
  end
end
