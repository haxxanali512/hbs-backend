class OrgAcceptedPlan < ApplicationRecord
  audited

  # =========================
  # Associations
  # =========================
  belongs_to :organization
  belongs_to :insurance_plan
  belongs_to :added_by, class_name: "User"
  has_many :plan_notes,
           -> { order(created_at: :desc) },
           class_name: "OrgAcceptedPlanNote",
           dependent: :destroy
  has_many :organization_activation_plan_steps, dependent: :destroy

  # =========================
  # Enums
  # =========================
  enum :status, {
    draft: 0,
    active: 1,
    inactive: 2,
    locked: 3
  }

  enum :network_type, {
    in_network: 0,
    out_of_network: 1
  }

  enum :enrollment_status, {
    pending: 0,
    verified: 1,
    denied: 2,
    not_applicable: 3
  }

  # =========================
  # Validations
  # =========================
  validates :organization_id, :insurance_plan_id, :network_type, :effective_date, :added_by_id, presence: true
  validates :insurance_plan_id, uniqueness: { scope: :organization_id, message: "ORG_PLAN_DUP" }
  validate :date_range_valid
  validate :insurance_plan_must_be_active
  validate :in_network_enrollment_verification

  # =========================
  # Scopes
  # =========================
  scope :active_only, -> { where(status: :active) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :in_network_only, -> { where(network_type: :in_network) }
  scope :out_of_network_only, -> { where(network_type: :out_of_network) }
  scope :current, -> { where("effective_date <= ? AND (end_date IS NULL OR end_date >= ?)", Date.current, Date.current) }

  # =========================
  # Callbacks
  # =========================
  before_validation :set_default_enrollment_status
  after_save :auto_activate_if_dates_valid
  after_save :inactivate_if_date_passed
  after_save :create_enrollment_task_if_in_network
  after_commit :create_enrollment_support_ticket, on: :create

  # =========================
  # Business Logic
  # =========================
  def activate!
    update!(status: :active)
  end

  def inactivate!
    update!(status: :inactive)
  end

  def lock!(reason: nil)
    update!(status: :locked, notes: [ notes, "Locked: #{reason}" ].compact.join("\n\n"))
  end

  def unlock!
    update!(status: :active) if locked?
  end

  def is_current?
    return false unless active?
    return true if effective_date <= Date.current && (end_date.nil? || end_date >= Date.current)
    false
  end

  def can_be_deleted?
    # Cannot be hard-deleted; must be inactivated
    false
  end

  def requires_enrollment_verification?
    in_network? && enrollment_status == :pending
  end

  def status_badge_class
    case status
    when "draft" then "bg-gray-100 text-gray-800"
    when "active" then "bg-green-100 text-green-800"
    when "inactive" then "bg-red-100 text-red-800"
    when "locked" then "bg-yellow-100 text-yellow-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def network_type_badge_class
    case network_type
    when "in_network" then "bg-blue-100 text-blue-800"
    when "out_of_network" then "bg-orange-100 text-orange-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def enrollment_status_badge_class
    case enrollment_status
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "verified" then "bg-green-100 text-green-800"
    when "denied" then "bg-red-100 text-red-800"
    when "not_applicable" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  # =========================
  # Private Methods
  # =========================
  private

  def set_default_enrollment_status
    return if enrollment_status.present?

    self.enrollment_status = if out_of_network?
      :not_applicable
    else
      :pending
    end
  end

  def date_range_valid
    return unless effective_date.present? && end_date.present?

    if effective_date > end_date
      errors.add(:base, "ORG_PLAN_DATE")
    end
  end

  def insurance_plan_must_be_active
    return unless insurance_plan

    unless insurance_plan.active?
      errors.add(:insurance_plan_id, "Insurance plan must be active")
    end
  end

  def in_network_enrollment_verification
    nil unless in_network? && enrollment_status == :pending

    # This will create a task for HBS to verify enrollment
    # The validation passes but a task is created
  end

  def auto_activate_if_dates_valid
    return unless draft?
    return unless effective_date.present? && effective_date <= Date.current
    return unless end_date.nil? || end_date >= Date.current

    activate!
  end

  def inactivate_if_date_passed
    return unless active?
    return unless end_date.present? && end_date < Date.current

    inactivate!
  end

  def create_enrollment_task_if_in_network
    return unless saved_change_to_network_type?
    nil unless in_network? && enrollment_status == :pending

    # TODO: Create task for HBS enrollment verification
    # Task.create!(
    #   organization_id: organization_id,
    #   task_type: :enrollment_verification,
    #   reference_type: "OrgAcceptedPlan",
    #   reference_id: id,
    #   description: "Verify enrollment for #{insurance_plan.name} (in-network)"
    # )
  end

  def create_enrollment_support_ticket
    return unless requires_enrollment_verification?

    creator = if added_by&.client_user?
      added_by
    elsif organization&.owner&.client_user?
      organization.owner
    end

    return unless creator.present?

    subject = "Enrollment Verification Needed: #{insurance_plan.name}"

    return if SupportTicket.where(organization_id: organization_id, subject: subject).exists?

    SupportTicket.create!(
      organization: organization,
      created_by_user: creator,
      category: :general_question,
      priority: :normal,
      subject: subject,
      description: "Organization #{organization.name} requested enrollment verification for #{insurance_plan.name} (#{network_type.humanize}). Please review and process this enrollment."
    )
  rescue => e
    Rails.logger.error("Failed to create enrollment support ticket for OrgAcceptedPlan #{id}: #{e.message}")
  end
end
