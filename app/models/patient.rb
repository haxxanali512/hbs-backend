class Patient < ApplicationRecord
  include Discard::Model
  include AASM

  audited

  belongs_to :organization
  has_many :appointments, dependent: :restrict_with_error
  has_many :encounters, dependent: :restrict_with_error
  has_many :claims, dependent: :restrict_with_error
  has_many :patient_insurance_coverages, dependent: :restrict_with_error
  has_many :documents, as: :documentable, dependent: :destroy
  has_one :prescription, dependent: :destroy
  belongs_to :merged_into_patient, optional: true, class_name: "Patient", foreign_key: "merged_into_patient_id"
  has_many :merged_patients, class_name: "Patient", foreign_key: "merged_into_patient_id"

  # Virtual attribute for EZClaim push flag
  attr_accessor :push_to_ezclaim

  # Nested attributes
  accepts_nested_attributes_for :patient_insurance_coverages, allow_destroy: true, reject_if: :all_blank

  # Enums
  enum :status, {
    active: 0,
    inactive: 1,
    deceased: 2,
    merged: 3
  }

  # AASM State Machine
  aasm column: "status", enum: true do
    state :active, initial: true
    state :inactive
    state :deceased
    state :merged

    event :activate do
      transitions from: :inactive, to: :active
    end

    event :inactivate do
      transitions from: :active, to: :inactive,
                  after: :ensure_no_future_activities
    end

    event :mark_deceased, after: :set_deceased_timestamp do
      transitions from: [ :active, :inactive ], to: :deceased,
                  after: :block_new_encounters
    end

    event :merge_into_target do
      transitions to: :merged
    end

    event :reactivate do
      transitions from: :inactive, to: :active
    end
  end

  # Validations
  validates :first_name, :last_name, presence: true
  validates :first_name, :last_name, length: { minimum: 2, maximum: 100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone_number, format: { with: /\A\+?[1-9]\d{1,14}\z/ }, allow_blank: true
  validates :mrn, uniqueness: { scope: :organization_id, case_sensitive: false }, allow_blank: true
  validates :external_id, uniqueness: { scope: :organization_id }, allow_blank: true
  validate :date_of_birth_not_in_future
  validate :address_required
  validate :mrn_required_if_org_enabled
  validate :immutable_fields_if_deceased_or_merged
  validate :can_edit_demographics
  validate :merge_target_valid, if: :merging?

  # Callbacks
  after_create :push_to_ezclaim_if_requested

  accepts_nested_attributes_for :prescription, update_only: true

  # Scopes
  scope :active_patients, -> { where(status: :active) }
  scope :by_status, ->(status) { where(status: status) }
  scope :search, ->(term) {
    where(
      "first_name ILIKE ? OR last_name ILIKE ? OR mrn ILIKE ? OR email ILIKE ? OR phone_number ILIKE ?",
      "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%"
    )
  }
  scope :recent, -> { order(created_at: :desc) }

  # Instance Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name
  end

  def age
    return nil unless dob.present?
    ((Date.current - dob) / 365.25).floor
  end

  def formatted_dob
    dob&.strftime("%B %d, %Y")
  end

  def full_address
    parts = [ address_line_1, address_line_2, city, state, postal, country ].compact.reject(&:blank?)
    parts.join(", ")
  end

  def status_badge_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "inactive" then "bg-gray-100 text-gray-800"
    when "deceased" then "bg-red-100 text-red-800"
    when "archived" then "bg-yellow-100 text-yellow-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def is_deceased?
    deceased_at.present? || status == "deceased"
  end

  def is_merged?
    status == "merged"
  end

  def can_be_deleted?
    false
  end

  def can_edit_demographics?
    !is_deceased? && !is_merged?
  end

  def has_future_activities?
    future_date = Time.current.beginning_of_day
    appointments.upcoming.any? || encounters.where("date_of_service > ?", future_date).any?
  end

  def merging?
    @merging == true
  end

  def set_merging
    @merging = true
  end

  private

  # Validations
  def date_of_birth_not_in_future
    return unless dob.present?

    if dob > Date.current
      errors.add(:dob, "PAT_DOB_FUTURE - Date of birth cannot be in the future")
    end
  end

  def address_required
    if address_line_1.blank? && address_line_2.blank?
      errors.add(:base, "PAT_ADDR_REQUIRED - Patient address is required")
    end
  end

  def mrn_required_if_org_enabled
    return unless organization.present?

    org_settings = organization.organization_setting
    if org_settings&.mrn_enabled == "true" && mrn.blank?
      errors.add(:mrn, "PAT_MRN_REQUIRED - MRN is required for this organization")
    end
  end

  def immutable_fields_if_deceased_or_merged
    return unless (is_deceased? || is_merged?) && persisted?

    immutable_fields = [ :first_name, :last_name, :dob, :mrn, :email, :phone_number, :address_line_1, :address_line_2 ]
    changed_fields = immutable_fields.select { |field| public_send("#{field}_changed?") && public_send(field).present? }

    if changed_fields.any?
      errors.add(:base, "PAT_EDIT_IMMUTABLE_STATE - Record cannot be edited in this state. Use emergency override for critical corrections.")
    end
  end

  def can_edit_demographics
    return if new_record?
    return if can_edit_demographics?

    demographic_fields = [ :first_name, :last_name, :dob, :sex_at_birth, :email, :phone_number, :address_line_1, :address_line_2 ]
    changed_demographics = demographic_fields.any? { |field| public_send("#{field}_changed?") }

    if changed_demographics
      errors.add(:base, "PAT_EDIT_IMMUTABLE_STATE - Demographics cannot be edited for deceased or merged patients")
    end
  end

  def merge_target_valid
    return unless merging?

    target = merged_into_patient
    unless target.present? && target.organization_id == organization_id && target.active?
      errors.add(:merged_into_patient_id, "PAT_MERGE_TARGET_INVALID - Target patient must be in the same organization and active")
    end

    if is_deceased? || is_merged?
      errors.add(:base, "PAT_MERGE_FORBIDDEN - Cannot merge a deceased or already merged record")
    end
  end

  # State machine callbacks
  def set_deceased_timestamp
    self.deceased_at = Time.current unless deceased_at.present?
  end

  def block_new_encounters
    # System will check this status when creating encounters
    # Encounter model validation will block if patient is deceased
  end

  def ensure_no_future_activities
    if has_future_activities?
      errors.add(:base, "PAT_INACT_WITH_FUTURE_ENC - Cancel future appointments and encounters before inactivating")
      throw(:abort)
    end
  end

  def push_to_ezclaim_if_requested
    return unless push_to_ezclaim == true || push_to_ezclaim == "1"
    return unless organization&.organization_setting&.ezclaim_enabled?

    begin
      service = EzclaimService.new(organization: organization)

      # Map patient fields to EZClaim fields
      patient_data = {
        PatFirstName: first_name,
        PatLastName: last_name,
        PatCity: city,
        PatAddress: address_line_1,
        PatZip: postal,
        PatBirthDate: dob&.strftime("%Y-%m-%d"),
        PatState: state,
        PatSex: sex_at_birth
      }

      result = service.create_patient(patient_data)

      if result[:success]
        Rails.logger.info "Patient #{id} successfully pushed to EZClaim"
      else
        Rails.logger.error "Failed to push patient #{id} to EZClaim: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Error pushing patient #{id} to EZClaim: #{e.message}"
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end

  # Merge functionality (placeholder)
  def merge_with(target_patient)
    self.merging = true
    self.merged_into_patient = target_patient
    self.merged_into_patient_id = target_patient.id

    if save
      merge_into_target!
      # Log merge event
      Rails.logger.info "Patient #{id} merged into #{target_patient.id}"
    end

    self.merging = false
  end
end
