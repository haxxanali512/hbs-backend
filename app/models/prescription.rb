class Prescription < ApplicationRecord
  include Discard::Model

  audited

  # Associations
  belongs_to :organization
  belongs_to :patient
  belongs_to :specialty, optional: true
  belongs_to :procedure_code, optional: true
  belongs_to :provider, optional: true

  # Many-to-many associations
  has_many :prescription_diagnosis_codes, dependent: :destroy
  has_many :diagnosis_codes, through: :prescription_diagnosis_codes

  # Documents now use Active Storage
  has_many_attached :documents

  # Virtual attributes for form handling
  attr_accessor :diagnosis_code_ids

  # Validations
  validates :expires_on, presence: true
  validates :title, presence: true
  validates :date_written, presence: true
  validates :organization_id, presence: true
  validate :date_written_not_in_future
  validate :expires_after_written

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
