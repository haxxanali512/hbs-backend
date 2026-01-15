class PatientInsuranceCoverage < ApplicationRecord
  audited

  # =========================
  # Associations
  # =========================
  belongs_to :organization
  belongs_to :patient, optional: true
  belongs_to :insurance_plan
  belongs_to :last_eligibility_check, class_name: "EligibilityCheck", optional: true
  has_many :eligibility_checks, dependent: :nullify
  has_many :encounters, dependent: :restrict_with_error
  has_many :claims, dependent: :restrict_with_error

  # =========================
  # Enums
  # =========================
  enum :relationship_to_subscriber, {
    self: 0,
    spouse: 1,
    child: 2,
    other: 3
  }

  enum :coverage_order, {
    primary: 0,
    secondary: 1,
    tertiary: 2
  }

  enum :status, {
    draft: 0,
    active: 1,
    terminated: 2,
    replaced: 3
  }

  # =========================
  # Validations
  # =========================
  validates :patient_id, presence: true, unless: -> { patient.present? && patient_id.blank? }
  validates :organization_id, :insurance_plan_id, :member_id, :subscriber_name,
            :relationship_to_subscriber, :coverage_order, presence: true
  validates :member_id, length: { in: 1..30 }, format: { with: /\A[A-Za-z0-9\-]+\z/, message: "COV_MEMBER_ID_INVALID" }
  validates :subscriber_name, length: { in: 1..200 }
  validates :subscriber_address, presence: true
  validates :insurance_plan_id, presence: { message: "COV_PLAN_REQUIRED" }
  validate :date_range_valid
  validate :member_id_unique_per_patient_plan
  validate :no_duplicate_primary
  validate :plan_must_be_active
  validate :plan_must_be_accepted_by_org
  validate :delete_blocked_if_referenced, on: :destroy

  # =========================
  # Scopes
  # =========================
  scope :active_only, -> { where(status: :active) }
  scope :for_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :primary_only, -> { where(coverage_order: :primary) }
  scope :current, -> { where("(effective_date IS NULL OR effective_date <= ?) AND (termination_date IS NULL OR termination_date >= ?)", Date.current, Date.current) }

  # =========================
  # Callbacks
  # =========================
  before_validation :normalize_member_id
  before_validation :normalize_subscriber_name
  before_validation :validate_subscriber_address_structure
  after_save :auto_activate_if_dates_valid
  after_save :terminate_if_date_passed

  # =========================
  # Business Logic
  # =========================
  def activate!
    update!(status: :active)
  end

  def terminate!(termination_date: Date.current, actor: nil)
    update!(status: :terminated, termination_date: termination_date)
  end

  def replace!(new_coverage_id:)
    update!(status: :replaced)
  end

  def is_current?
    return false unless active?
    return true if effective_date.nil? && termination_date.nil?
    return false if effective_date.present? && effective_date > Date.current
    return false if termination_date.present? && termination_date < Date.current
    true
  end

  def can_be_deleted?
    return false if encounters.exists?
    return false if claims.exists?
    true
  end

  def status_badge_class
    case status
    when "draft" then "bg-gray-100 text-gray-800"
    when "active" then "bg-green-100 text-green-800"
    when "terminated" then "bg-red-100 text-red-800"
    when "replaced" then "bg-yellow-100 text-yellow-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  # =========================
  # Private Methods
  # =========================
  private

  def normalize_member_id
    return unless member_id.present?

    self.member_id = member_id.strip.upcase
  end

  def normalize_subscriber_name
    return unless subscriber_name.present?

    self.subscriber_name = subscriber_name.strip.gsub(/\s+/, " ")
  end

  def validate_subscriber_address_structure
    return unless subscriber_address.present?

    required_fields = %w[line1 city state postal country]
    missing = required_fields - subscriber_address.keys
    if missing.any?
      errors.add(:subscriber_address, "Missing required fields: #{missing.join(', ')}")
    end
  end

  def date_range_valid
    return unless effective_date.present? && termination_date.present?

    if effective_date > termination_date
      errors.add(:base, "COV_DATE_RANGE_INVALID")
    end
  end

  def member_id_unique_per_patient_plan
    return unless patient_id.present? && insurance_plan_id.present? && member_id.present?

    existing = PatientInsuranceCoverage
      .where(patient_id: patient_id, insurance_plan_id: insurance_plan_id, member_id: member_id)
      .where.not(id: id)

    if existing.exists?
      errors.add(:member_id, "Member ID already exists for this patient and plan")
    end
  end

  def no_duplicate_primary
    return unless patient_id.present? && organization_id.present?
    return unless coverage_order.to_s == "primary" && (active? || draft?)

    existing = PatientInsuranceCoverage
      .where(patient_id: patient_id, organization_id: organization_id, coverage_order: :primary)
      .where(status: [ :draft, :active ])
      .where.not(id: id)

    if existing.exists?
      errors.add(:coverage_order, "COV_DUPLICATE_PRIMARY")
    end
  end

  def plan_must_be_active
    return unless insurance_plan

    unless insurance_plan.active?
      errors.add(:insurance_plan_id, "Insurance plan must be active")
    end
  end

  def plan_must_be_accepted_by_org
    return unless organization && insurance_plan

    accepted_plan = organization.org_accepted_plans.active_only
                                 .current
                                 .find_by(insurance_plan_id: insurance_plan_id)

    unless accepted_plan
      errors.add(:insurance_plan_id, "PLAN_NOT_ACCEPTED")
      return
    end

    unless %w[verified not_applicable].include?(accepted_plan.enrollment_status.to_s)
      errors.add(:insurance_plan_id, "PLAN_ENROLLMENT_NOT_VERIFIED")
      return
    end

    provider_enrolled = organization.payer_enrollments
                                     .where(status: :approved)
                                     .where(payer_id: insurance_plan.payer_id)
                                     .where.not(provider_id: nil)
                                     .exists?

    unless provider_enrolled
      errors.add(:insurance_plan_id, "PROVIDER_NOT_ENROLLED")
    end
  end

  def delete_blocked_if_referenced
    return if can_be_deleted?

    errors.add(:base, "COV_DELETE_FORBIDDEN")
    throw(:abort)
  end

  def auto_activate_if_dates_valid
    return unless draft?
    return unless is_current?

    activate!
  end

  def terminate_if_date_passed
    return unless active?
    return unless termination_date.present? && termination_date < Date.current

    terminate!(termination_date: termination_date)
  end
end
