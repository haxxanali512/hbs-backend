class Encounter < ApplicationRecord
  include Discard::Model
  include AASM

  audited

  # ===========================================================
  # ASSOCIATIONS
  # ===========================================================

  # Core belongs_to
  belongs_to :organization
  belongs_to :patient
  belongs_to :provider
  belongs_to :specialty
  belongs_to :organization_location, optional: true
  belongs_to :appointment, optional: true

  # Billing/Cascade (mutually exclusive)
  belongs_to :claim, optional: true, class_name: "Claim"
  belongs_to :patient_invoice, optional: true
  belongs_to :eligibility_check_used, optional: true, class_name: "EligibilityCheck"
  belongs_to :confirmed_by, optional: true, class_name: "User"

  # has_one (mutually exclusive primary items)
  has_one :claim, as: :claimable # Placeholder
  has_one :patient_invoice, as: :invoiceable # Placeholder
  has_one :primary_clinical_documentation, -> { where(is_primary: true) }, class_name: "ClinicalDocumentation"

  # has_many
  has_many :encounter_diagnosis_codes, dependent: :destroy
  has_many :diagnosis_codes, through: :encounter_diagnosis_codes
  # has_many :encounter_procedure_items, dependent: :destroy
  # has_many :clinical_documentations, as: :documentable, dependent: :restrict_with_error
  # has_many :encounter_comments, dependent: :destroy
  # has_many :encounter_tasks, dependent: :destroy
  has_many :documents, as: :documentable, dependent: :destroy

  # ===========================================================
  # ENUMS
  # ===========================================================

  enum :billing_channel, {
    insurance: 0,
    self_pay: 1
  }

  enum :status, {
    planned: 0,
    ready_for_review: 1,
    cancelled: 2,
    completed_confirmed: 3
  }

  enum :display_status, {
    not_started: 0,
    in_progress: 1,
    awaiting_confirmation: 2,
    confirmed: 3,
    claim_generated: 4,
    claim_submitted: 5,
    claim_approved: 6,
    claim_paid: 7,
    claim_denied: 8,
    invoice_created: 9,
    invoice_paid: 10,
    finalized_paid: 11,
    finalized_denied: 12,
    error: 13
  }

  enum :billing_insurance_status, {
    no_coverage: 0,
    coverage_pending: 1,
    coverage_verified: 2,
    auth_required: 3,
    auth_approved: 4,
    auth_denied: 5
  }

  # ===========================================================
  # AASM STATE MACHINE
  # ===========================================================

  aasm column: "status", enum: true do
    state :planned, initial: true
    state :ready_for_review
    state :cancelled
    state :completed_confirmed

    event :mark_ready_for_review do
      transitions from: :planned, to: :ready_for_review,
                  after: :update_display_status_to_awaiting_confirmation,
                  if: :validate_blocking_checks
    end

    event :cancel do
      transitions from: [ :planned, :ready_for_review ], to: :cancelled,
                  after: :update_display_status_to_cancelled,
                  if: :can_be_cancelled?
    end

    event :confirm_completed do
      transitions from: [ :ready_for_review ], to: :completed_confirmed,
                  after: :handle_cascade_and_snapshots,
                  if: :can_be_confirmed?
    end
  end

  # ===========================================================
  # VALIDATIONS
  # ===========================================================

  validates :date_of_service, presence: true
  validates :organization_id, presence: true
  validates :patient_id, presence: true
  validates :provider_id, presence: true
  validates :specialty_id, presence: true
  validates :billing_channel, presence: true

  # Custom validations
  validate :date_of_service_not_in_future
  validate :provider_assigned_to_organization
  validate :specialty_valid_and_active
  validate :diagnosis_codes_required
  validate :insurance_requirements_if_insurance_billing
  validate :procedure_codes_allowed_for_specialty
  validate :no_post_cascade_modifications
  validate :exactly_one_billing_document
  validate :patient_not_deceased

  # ===========================================================
  # SCOPES
  # ===========================================================

  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :by_provider, ->(provider_id) { where(provider_id: provider_id) }
  scope :by_specialty, ->(specialty_id) { where(specialty_id: specialty_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_billing_channel, ->(channel) { where(billing_channel: channel) }
  scope :cascaded, -> { where(cascaded: true) }
  scope :not_cascaded, -> { where(cascaded: false) }
  scope :awaiting_confirmation, -> { where(display_status: :awaiting_confirmation) }
  scope :cancelled_encounters, -> { where(status: :cancelled) }
  scope :recent, -> { order(date_of_service: :desc, created_at: :desc) }

  # ===========================================================
  # CALLBACKS
  # ===========================================================

  before_save :ensure_cascade_fields_locked, if: :cascaded?
  after_create :fire_encounter_created_event
  after_update :fire_status_updated_event, if: :saved_change_to_status?

  # ===========================================================
  # INSTANCE METHODS
  # ===========================================================

  def insurance_billing?
    insurance? && billing_channel == "insurance"
  end

  def self_pay?
    billing_channel == "self_pay"
  end

  def can_be_cancelled?
    !cascaded? && date_of_service.present? && date_of_service >= Date.current
  end

  def can_be_confirmed?
    return false if cascaded?
    return false if date_of_service.blank?

    # Can confirm if DOS is today or in the past
    date_of_service <= Date.current && validate_blocking_checks
  end

  def cascaded?
    cascaded == true
  end

  def has_billing_document?
    claim_id.present? || patient_invoice_id.present?
  end

  def billing_document_type
    return "claim" if claim_id.present?
    return "invoice" if patient_invoice_id.present?
    nil
  end

  def locked_for_correction?
    cascaded? && locked_for_correction == true
  end

  def status_badge_color
    case status
    when "planned" then "bg-gray-100 text-gray-800"
    when "ready_for_review" then "bg-blue-100 text-blue-800"
    when "cancelled" then "bg-red-100 text-red-800"
    when "completed_confirmed" then "bg-green-100 text-green-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def display_status_text
    display_status.humanize
  end

  # ===========================================================
  # PRIVATE METHODS
  # ===========================================================

  private

  # State machine callbacks
  def update_display_status_to_awaiting_confirmation
    update!(display_status: :awaiting_confirmation)
  end

  def update_display_status_to_cancelled
    update!(display_status: :error)
  end

  def handle_cascade_and_snapshots
    return false unless can_be_confirmed?

    # Capture snapshots
    capture_coverage_snapshot if insurance?
    capture_pricing_snapshot

    # Cascade to billing document
    if insurance?
      generate_claim_and_submission
    else
      generate_patient_invoice
    end

    # Mark as cascaded and lock
    update!(
      cascaded: true,
      cascaded_at: Time.current,
      confirmed_at: Time.current
    )

    # Update display status
    update!(display_status: :claim_generated) if insurance?
    update!(display_status: :invoice_created) if self_pay?

    fire_cascade_event
  end

  # Validations
  def date_of_service_not_in_future
    if date_of_service.present? && date_of_service > Date.current && status_changed?
      errors.add(:date_of_service, "ENC_DOS_IN_FUTURE - Cannot confirm encounter with future date of service")
    end
  end

  def provider_assigned_to_organization
    return unless provider.present? && organization.present?

    unless provider.provider_assignments.exists?(organization_id: organization.id, active: true)
      errors.add(:provider_id, "PROVIDER_NOT_ASSIGNED_TO_ORG - Provider must have active assignment to organization")
    end
  end

  def specialty_valid_and_active
    return unless specialty.present?

    unless specialty.active?
      errors.add(:specialty_id, "ENC_SPECIALTY_INVALID - Specialty must be active")
    end
  end

  def diagnosis_codes_required
    if diagnosis_codes.empty?
      errors.add(:base, "ENC_DX_REQUIRED - At least one diagnosis code is required")
    else
      # Check that all diagnosis codes are active
      inactive_codes = diagnosis_codes.where(status: :retired)
      if inactive_codes.any?
        codes_list = inactive_codes.pluck(:code).join(", ")
        errors.add(:base, "DX_CODE_RETIRED - The following diagnosis codes are retired and cannot be newly assigned: #{codes_list}")
      end
    end
  end

  def insurance_requirements_if_insurance_billing
    nil unless insurance?

    # Placeholder validations - will be implemented when PatientInsuranceCoverage model exists
    # Check coverage exists and is active on DOS
    # Check plan is accepted by organization
    # Check payer enrollment
    # Check prior authorization requirements
  end

  def procedure_codes_allowed_for_specialty
    # Placeholder - will validate when encounter_procedure_items exist
    # Each CPT code must be allowed for the specialty
  end

  def no_post_cascade_modifications
    if cascaded? && (
        date_of_service_changed? ||
        provider_id_changed? ||
        patient_id_changed? ||
        specialty_id_changed?
    )
      errors.add(:base, "ENC_POST_CASCADE_CORRECTION_REQUIRED - Critical fields are locked after cascade. Use correction workflow.")
    end
  end

  def exactly_one_billing_document
    count = [ claim_id.present?, patient_invoice_id.present? ].count(true)
    if count > 1
      errors.add(:base, "Cannot have both claim and invoice")
    end
  end

  def patient_not_deceased
    return unless patient.present?

    if patient.is_deceased?
      errors.add(:patient_id, "Cannot create encounters for deceased patients")
    end
  end

  def ensure_cascade_fields_locked
    # Prevent modification of locked fields
    if cascaded? && date_of_service_changed?
      raise ActiveRecord::RecordNotSaved, "ENC_POST_CASCADE_CORRECTION_REQUIRED"
    end
  end

  def validate_blocking_checks
    # Check all blocking validations
    valid? && (
      diagnosis_codes.exists? &&
      provider.provider_assignments.active.exists?(organization_id: organization.id)
    )
  end

  def capture_coverage_snapshot
    # Placeholder: capture insurance coverage details
    update!(coverage_snapshot: {
      captured_at: Time.current
      # TODO: Add actual coverage data when model exists
    })
  end

  def capture_pricing_snapshot
    # Placeholder: capture pricing details
    update!(pricing_snapshot: {
      captured_at: Time.current
      # TODO: Add actual pricing data
    })
  end

  def generate_claim_and_submission
    # Placeholder: Create claim and submission
    # Will be implemented when Claim model is fully built
    Rails.logger.info "Generating claim for encounter #{id}"
  end

  def generate_patient_invoice
    # Placeholder: Create patient invoice
    # Will be implemented when PatientInvoice model is fully built
    Rails.logger.info "Generating invoice for encounter #{id}"
  end

  def fire_encounter_created_event
    # Event firing - placeholder
    Rails.logger.info "Event: encounter.created for encounter #{id}"
  end

  def fire_status_updated_event
    Rails.logger.info "Event: encounter.status_updated for encounter #{id}, new status: #{status}"
  end

  def fire_cascade_event
    if insurance?
      Rails.logger.info "Event: encounter.claim_generated for encounter #{id}"
    elsif self_pay?
      Rails.logger.info "Event: encounter.patient_invoice_created for encounter #{id}"
    end
  end
end
