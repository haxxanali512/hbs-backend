class Encounter < ApplicationRecord
  include Discard::Model
  include AASM

  audited
  # Core belongs_to
  belongs_to :organization
  belongs_to :patient
  belongs_to :provider
  belongs_to :specialty
  belongs_to :encounter_template, optional: true
  belongs_to :organization_location, optional: true
  belongs_to :appointment, optional: true

  # Billing/Cascade (mutually exclusive)
  has_one :claim, foreign_key: "encounter_id", dependent: :restrict_with_error
  belongs_to :patient_invoice, optional: true
  belongs_to :patient_insurance_coverage, optional: true
  belongs_to :eligibility_check_used, optional: true, class_name: "EligibilityCheck"
  belongs_to :confirmed_by, optional: true, class_name: "User"

  # has_one (mutually exclusive primary items)
  # has_one :patient_invoice, as: :invoiceable # Placeholder
  has_one :primary_clinical_documentation, -> { where(is_primary: true) }, class_name: "ClinicalDocumentation"

  # has_many
  has_many :encounter_diagnosis_codes, dependent: :destroy
  has_many :diagnosis_codes, through: :encounter_diagnosis_codes
  has_many :encounter_procedure_items, dependent: :destroy
  has_many :procedure_codes, through: :encounter_procedure_items
  # has_many :clinical_documentations, as: :documentable, dependent: :restrict_with_error
  has_many :encounter_comments, dependent: :destroy
  has_many :encounter_comment_seens, dependent: :destroy
  has_many :provider_notes, dependent: :destroy
  # has_many :encounter_tasks, dependent: :destroy
  # Documents now use Active Storage
  has_many_attached :documents

  # Virtual attributes for workflow-based procedure capture
  attr_accessor :procedure_code_ids, :primary_procedure_code_id, :duration_minutes
  attr_accessor :diagnosis_code_ids
  attr_accessor :procedure_units, :procedure_modifiers


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
    reviewed: 2,
    ready_to_submit: 3,
    cancelled: 4,
    completed_confirmed: 5,
    sent: 6
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

  enum :place_of_service_code, {
    office: 11,
    patients_home: 12,
    telehealth: 10
  }

  # ===========================================================
  # AASM STATE MACHINE
  # ===========================================================

  aasm column: "status", enum: true do
    state :planned, initial: true
    state :ready_for_review
    state :reviewed
    state :ready_to_submit
    state :cancelled
    state :completed_confirmed
    state :sent

    event :mark_ready_for_review do
      transitions from: :planned, to: :ready_for_review,
                  after: :update_display_status_to_awaiting_confirmation,
                  if: :validate_blocking_checks
    end

    event :mark_reviewed do
      transitions from: :ready_for_review, to: :reviewed
    end

    event :mark_ready_to_submit do
      transitions from: :reviewed, to: :ready_to_submit
    end

    event :cancel do
      transitions from: [ :planned, :ready_for_review, :reviewed, :ready_to_submit ], to: :cancelled,
                  after: :update_display_status_to_cancelled,
                  if: :can_be_cancelled?
    end

    event :mark_sent do
      transitions from: :ready_to_submit, to: :sent,
                  after: :update_display_status_to_claim_submitted
    end

    event :confirm_completed do
      # Mark as completed_confirmed when submitted to billing
      transitions from: :ready_to_submit, to: :completed_confirmed,
                  after: :handle_cascade_and_snapshots
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
  # validates :billing_channel, presence: true

  # Custom validations
  validate :date_of_service_not_in_future
  # validate :provider_assigned_to_organization
  validate :specialty_valid_and_active
  validate :diagnosis_codes_required
  validate :insurance_requirements_if_insurance_billing
  validate :procedure_codes_allowed_for_specialty
  validate :no_post_cascade_modifications
  validate :exactly_one_billing_document
  validate :patient_not_deceased
  validate :procedure_codes_required_for_submission
  validate :procedure_code_rules_compliance

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
  after_save :associate_diagnosis_codes, if: -> { diagnosis_code_ids.present? }
  after_save :associate_procedure_codes, if: -> { procedure_code_ids.present? }
  after_save :create_claim_from_procedure_codes, if: :should_create_claim?
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

  # Get procedure codes from encounter_procedure_items (preferred) or claim lines (fallback)
  def all_procedure_codes
    if encounter_procedure_items.any?
      encounter_procedure_items.includes(:procedure_code).map(&:procedure_code)
    elsif claim.present?
      ProcedureCode.joins(:claim_lines).where(claim_lines: { claim_id: claim.id }).distinct
    else
      []
    end
  end

  # Legacy method - kept for backward compatibility
  def procedure_codes
    if encounter_procedure_items.any?
      ProcedureCode.joins(:encounter_procedure_items).where(encounter_procedure_items: { encounter_id: id })
    elsif claim.present?
      ProcedureCode.joins(:claim_lines).where(claim_lines: { claim_id: claim.id })
    else
      ProcedureCode.none
    end
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

  def update_display_status_to_claim_submitted
    update!(display_status: :claim_submitted)
  end

  def handle_cascade_and_snapshots
    # Capture snapshots
    capture_coverage_snapshot if insurance?
    capture_pricing_snapshot

    # Mark as cascaded and lock (encounter has been submitted to billing)
    update!(
      cascaded: true,
      cascaded_at: Time.current,
      confirmed_at: Time.current
    )

    # Update display status based on billing channel
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
    # Check virtual attribute first (for workflow form), then association
    dx_ids = Array(diagnosis_code_ids).reject(&:blank?)

    if dx_ids.any?
      # Using virtual attribute from workflow form - validation passes
      nil
    elsif diagnosis_codes.any?
      # Check that all diagnosis codes are active
      inactive_codes = diagnosis_codes.where(status: :retired)
      if inactive_codes.any?
        codes_list = inactive_codes.pluck(:code).join(", ")
        errors.add(:base, "DX_CODE_RETIRED - The following diagnosis codes are retired and cannot be newly assigned: #{codes_list}")
      end
    else
      # No diagnosis codes provided
      errors.add(:base, "ENC_DX_REQUIRED - At least one diagnosis code is required")
    end
  end

  # Linked resource helper for support tickets
  def self.patient_encounters(organization, patient_id)
    return none unless organization && patient_id.present?

    kept
      .where(organization_id: organization.id, patient_id: patient_id)
      .includes(:provider)
      .order(date_of_service: :desc)
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

  def procedure_codes_required_for_submission
    # Only validate if we're in the workflow (procedure_code_ids is set)
    # Handle both array and nil cases
    proc_ids = Array(procedure_code_ids).reject(&:blank?)
    return if proc_ids.empty? && procedure_code_ids.nil? # Skip if not in workflow mode

    if proc_ids.empty?
      errors.add(:procedure_code_ids, "At least one procedure code is required")
    elsif proc_ids.length > 5
      errors.add(:procedure_code_ids, "Maximum of 5 procedure codes allowed")
    end
  end


  def procedure_code_rules_compliance
    # Only validate if we're in the workflow (procedure_code_ids is set) or have procedure codes
    return unless procedure_code_ids.present? || encounter_procedure_items.any?

    validator = EncounterProcedureCodeValidator.new(self)
    result = validator.validate

    unless result[:valid]
      result[:errors].each do |error|
        errors.add(:base, error)
      end
    end
  end

  # Duration is no longer collected in the workflow form.

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

  def should_create_claim?
    # Create claim if we have procedure codes and this is an insurance encounter
    procedure_code_ids.present? && insurance? && claim.blank?
  end

  def associate_diagnosis_codes
    dx_ids = Array(diagnosis_code_ids).reject(&:blank?)
    return if dx_ids.empty?

    # Clear existing associations
    encounter_diagnosis_codes.destroy_all

    # Create new associations (limit to 5 as per workflow requirement)
    dx_ids.first(5).each do |dc_id|
      encounter_diagnosis_codes.find_or_create_by(diagnosis_code_id: dc_id.to_i)
    end
  end

  def associate_procedure_codes
    proc_ids = Array(procedure_code_ids).reject(&:blank?)
    return if proc_ids.empty?

    units_map = (procedure_units || {}).transform_keys(&:to_s)
    modifiers_map = (procedure_modifiers || {}).transform_keys(&:to_s)

    # Clear existing associations
    encounter_procedure_items.destroy_all

    # Create new associations
    # Set first one as primary if primary_procedure_code_id is provided, otherwise no primary
    proc_ids.each do |proc_code_id|
      is_primary = primary_procedure_code_id.present? && proc_code_id.to_i == primary_procedure_code_id.to_i
      encounter_procedure_items.find_or_create_by(
        procedure_code_id: proc_code_id.to_i
      ) do |item|
        item.is_primary = is_primary
        units_value = units_map[proc_code_id.to_s].to_i
        item.units = units_value.positive? ? units_value : 1
        modifier_value = modifiers_map[proc_code_id.to_s].to_s.strip
        item.modifiers = modifier_value.present? ? [ modifier_value ] : []
      end
    end

    # Ensure only one primary is set if any primary is specified
    if primary_procedure_code_id.present?
      primary_items = encounter_procedure_items.primary
      if primary_items.count > 1
        # Keep only the first one as primary
        primary_items.offset(1).update_all(is_primary: false)
      end
    end
  end

  def create_claim_from_procedure_codes
    proc_ids = Array(procedure_code_ids).reject(&:blank?)
    items = encounter_procedure_items.includes(:procedure_code)
    return if proc_ids.empty? && items.empty?

    # Create or find claim
    pos_code = resolved_place_of_service_code
    claim_record = claim || Claim.create!(
      organization_id: organization_id,
      encounter_id: id,
      patient_id: patient_id,
      provider_id: provider_id,
      specialty_id: specialty_id,
      place_of_service_code: pos_code,
      status: :generated,
      generated_at: Time.current
    )

    # Clear existing claim lines if any
    claim_record.claim_lines.destroy_all

    service_lines = if items.any?
      items.map do |item|
        {
          proc_code: item.procedure_code,
          units: item.units,
          modifiers: item.modifiers
        }
      end
    else
      proc_ids.map do |proc_code_id|
        { proc_code: ProcedureCode.find_by(id: proc_code_id.to_i), units: 1, modifiers: [] }
      end
    end

    # Create claim lines from procedure codes
    service_lines.each do |line|
      proc_code = line[:proc_code]
      next unless proc_code

      # Get pricing from fee schedule
      pricing_result = FeeSchedulePricingService.resolve_pricing(
        organization_id,
        provider_id,
        proc_code.id
      )

      units = line[:units].to_i > 0 ? line[:units].to_i : 1

      # Get unit price from pricing result
      unit_price = if pricing_result[:success]
        pricing_result[:pricing][:unit_price].to_f
      else
        0.0
      end

      # Calculate amount billed
      amount_billed = if pricing_result[:success] && pricing_result[:pricing][:pricing_rule] == "flat"
        # For flat pricing, amount is just the unit price
        unit_price
      else
        # For price_per_unit, amount is unit_price * units
        unit_price * units
      end

      # Create claim line
      claim_record.claim_lines.create!(
        procedure_code_id: proc_code.id,
        units: units,
        amount_billed: amount_billed,
        modifiers: line[:modifiers],
        place_of_service_code: pos_code,
        status: :generated
      )
    end

    # Update encounter to reference the claim
    update_column(:claim_id, claim_record.id) unless claim_id.present?
  end

  def resolved_place_of_service_code
    return place_of_service_code.to_s if place_of_service_code.present?

    organization_location&.place_of_service_code.to_s.presence || "11"
  end
end
