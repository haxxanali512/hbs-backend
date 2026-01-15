class SupportTicket < ApplicationRecord
  include Discard::Model

  audited

  CATEGORY_OPTIONS = {
    claims_issue: 0,
    portal_bug: 1,
    data_export: 3,
    general_question: 4,
    ownership_transfer: 5,
    invoice_issue: 6
  }.freeze

  CLAIMS_SUBCATEGORY_OPTIONS = {
    claim_status_follow_up: 0,
    denial_clarification: 1,
    underpayment: 2,
    deductible_eob_interpretation: 3,
    other: 4
  }.freeze

  PRIORITY_OPTIONS = {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3
  }.freeze

  STATUS_OPTIONS = {
    open: 0,
    in_progress: 1,
    waiting_on_client: 2,
    resolved: 3,
    closed: 4
  }.freeze

  STATUS_FLOW = {
    "open" => %w[in_progress waiting_on_client resolved],
    "in_progress" => %w[waiting_on_client resolved],
    "waiting_on_client" => %w[in_progress resolved],
    "resolved" => %w[closed in_progress],
    "closed" => %w[open]
  }.freeze

  ERROR_CODES = {
    missing_fields: "ST_MISSING_FIELDS",
    category_invalid: "ST_CATEGORY_INVALID",
    priority_forbidden: "ST_PRIORITY_FORBIDDEN",
    immutable_fields: "ST_IMMUTABLE_FIELDS",
    phi_detected: "ST_PHI_DETECTED",
    close_forbidden: "ST_CLOSE_FORBIDDEN",
    sla_breach: "ST_SLA_BREACH"
  }.freeze

  LINKED_RESOURCE_TYPES = {
    "Claim" => "Claim",
    "Encounter" => "Encounter",
    "Invoice" => "Invoice",
    "Agreement" => "Document"
  }.freeze

  SLA_FIRST_RESPONSE_HOURS = 72
  SLA_RESOLUTION_DAYS = 7

  belongs_to :organization
  belongs_to :created_by_user, class_name: "User"
  belongs_to :assigned_to_user, class_name: "User", optional: true

  has_many :comments,
           class_name: "SupportTicketComment",
           dependent: :destroy,
           inverse_of: :support_ticket

  has_many :tasks,
           class_name: "SupportTicketTask",
           dependent: :destroy,
           inverse_of: :support_ticket

  # Documents now use Active Storage
  has_many_attached :documents

  enum :category, CATEGORY_OPTIONS
  enum :sub_category, CLAIMS_SUBCATEGORY_OPTIONS
  enum :priority, PRIORITY_OPTIONS
  enum :status, STATUS_OPTIONS

  attr_readonly :subject, :description

  validates :organization,
            :created_by_user,
            :category,
            :subject,
            :description,
            :priority,
            :status,
            :first_response_due_at,
            :resolution_due_at,
            presence: true

  validates :subject, length: { minimum: 1, maximum: 200 }
  validate :require_subject_and_description
  validate :creator_membership
  validate :creator_scope
  validate :assignee_scope
  validate :linked_resource_consistency
  validate :status_transition_guard, if: -> { will_save_change_to_status? }
  validate :priority_guard, if: -> { will_save_change_to_priority? }
  validate :internal_notes_array
  validate :subject_phi_safe
  validate :description_phi_safe
  validate :claims_sub_category_required

  scope :for_org, ->(org_id) { where(organization_id: org_id) }
  scope :open_flow, -> { where(status: %i[open in_progress waiting_on_client]) }
  scope :resolved_flow, -> { where(status: %i[resolved closed]) }

  before_validation :apply_defaults, on: :create
  before_save :sync_closed_timestamp
  after_commit :schedule_sla_jobs, on: :create
  after_update_commit :reschedule_sla_jobs_if_needed

  def linked_resource
    return if linked_resource_type.blank? || linked_resource_id.blank?

    klass_name = LINKED_RESOURCE_TYPES[linked_resource_type]
    return unless klass_name && Object.const_defined?(klass_name)

    klass = klass_name.constantize
    klass.find_by(id: linked_resource_id)
  end

  def claims_issue?
    category == "claims_issue"
  end

  def append_internal_note!(body:, author:)
    guard_hbs!(author, :priority_forbidden, "Only HBS can add internal notes.")

    note = {
      "id" => SecureRandom.uuid,
      "body" => body,
      "author_id" => author.id,
      "author_name" => author.display_name,
      "created_at" => Time.current
    }

    with_lock do
      update!(internal_notes: (internal_notes.presence || []) + [ note ])
    end
  end

  def transition_status!(next_status, actor:)
    next_status = next_status.to_s
    return if status == next_status

    unless allowed_transition?(status, next_status)
      raise_support_error(:immutable_fields, "Invalid state transition.")
    end

    previous_status = status
    update!(status: next_status)
    schedule_auto_close_if_resolved if next_status == "resolved"

    SupportTicketEventPublisher.status_changed(self, actor, from: previous_status, to: next_status)
    SupportTicketMailer.status_changed(self, actor).deliver_later
  end

  def close!(actor:)
    guard_hbs!(actor, :close_forbidden, "Only HBS can close this ticket.")
    update!(status: :closed, closed_at: Time.current)
    SupportTicketEventPublisher.closed(self, actor)
    SupportTicketMailer.closed(self, actor).deliver_later
  end

  def reopen!(actor:)
    guard_hbs!(actor, :close_forbidden, "Only HBS can reopen this ticket.")
    update!(status: :open, closed_at: nil)
    SupportTicketEventPublisher.reopened(self, actor)
    SupportTicketMailer.reopened(self, actor).deliver_later
  end

  def escalate_priority!(actor:, reason: nil)
    return if urgent?

    previous_priority = priority
    next_priority = PRIORITY_OPTIONS.keys[PRIORITY_OPTIONS.keys.index(priority.to_sym) + 1]
    update!(priority: next_priority)

    SupportTicketEventPublisher.priority_changed(self, actor, from: previous_priority, to: next_priority)
    SupportTicketMailer.priority_changed(self, actor, reason: reason).deliver_later
  end

  def breach!(type)
    tasks.create!(
      task_type: type,
      status: :open,
      opened_at: Time.current,
      notes: "#{type} SLA breached"
    )

    escalate_priority!(actor: assigned_to_user || created_by_user, reason: "#{type} SLA breach")
    SupportTicketEventPublisher.sla_breached(self, type)
    SupportTicketMailer.sla_breach(self, type).deliver_later
  end

  private

  def apply_defaults
    self.priority ||= :low
    self.status ||= :open
    self.attachments ||= []
    self.internal_notes ||= []

    base_time = created_at || Time.current
    self.first_response_due_at ||= base_time + SLA_FIRST_RESPONSE_HOURS.hours
    self.resolution_due_at ||= base_time + SLA_RESOLUTION_DAYS.days
  end

  def sync_closed_timestamp
    return unless will_save_change_to_status?

    if status == "closed"
      self.closed_at ||= Time.current
    elsif status_before_last_save == "closed"
      self.closed_at = nil
    end
  end

  def schedule_sla_jobs
    SupportTicketSlaJob.set(wait_until: first_response_due_at).perform_later(id, "first_response")
    SupportTicketSlaJob.set(wait_until: resolution_due_at).perform_later(id, "resolution")
  end

  def reschedule_sla_jobs_if_needed
    return unless saved_change_to_first_response_due_at? || saved_change_to_resolution_due_at?

    schedule_sla_jobs
  end

  def schedule_auto_close_if_resolved
    SupportTicketAutoCloseJob.set(wait_until: 7.days.from_now)
                             .perform_later(id, Time.current.to_s)
  end

  def require_subject_and_description
    return if subject.present? && description.present?

    errors.add(:base, "[#{ERROR_CODES[:missing_fields]}] Subject and description are required.")
  end

  def creator_membership
    return unless organization && created_by_user

    membership_exists = organization.organization_memberships
                                     .active
                                     .exists?(user_id: created_by_user.id)

    return if membership_exists || created_by_user.hbs_user?

    errors.add(:created_by_user_id, "must belong to organization")
  end

  def creator_scope
    return unless created_by_user
    return if created_by_user.client_user?

    errors.add(:created_by_user_id, "must be a client user")
  end

  def assignee_scope
    return if assigned_to_user.blank? || assigned_to_user.hbs_user?

    errors.add(:assigned_to_user_id, "[#{ERROR_CODES[:priority_forbidden]}] Assigned user must be HBS.")
  end

  def linked_resource_consistency
    return if linked_resource_type.blank? && linked_resource_id.blank?

    unless LINKED_RESOURCE_TYPES.key?(linked_resource_type)
      errors.add(:linked_resource_type, "[#{ERROR_CODES[:category_invalid]}] Unknown linked resource type.")
      return
    end

    resource = linked_resource
    if resource.blank?
      errors.add(:linked_resource_id, "Linked resource not found.")
      return
    end

    resource_org_id =
      if resource.respond_to?(:organization_id)
        resource.organization_id
      elsif resource.respond_to?(:organization)
        resource.organization&.id
      end

    if resource_org_id.present? && resource_org_id != organization_id
      errors.add(:linked_resource_id, "Linked resource must belong to the same organization.")
    end
  end

  def status_transition_guard
    previous_status = status_before_last_save || status_was
    return if previous_status.blank?

    unless allowed_transition?(previous_status, status)
      errors.add(:status, "[#{ERROR_CODES[:immutable_fields]}] Invalid transition from #{previous_status} to #{status}.")
    end
  end

  def claims_sub_category_required
    return unless claims_issue?

    if sub_category.blank?
      errors.add(:sub_category, "COV_CLAIMS_SUBCATEGORY_REQUIRED")
    end
  end

  def allowed_transition?(from_status, to_status)
    STATUS_FLOW.fetch(from_status.to_s, []).include?(to_status.to_s)
  end

  def priority_guard
    return if assigned_to_user&.hbs_user? || created_by_user&.hbs_user?

    errors.add(:priority, "[#{ERROR_CODES[:priority_forbidden]}] Only HBS can change priority.")
  end

  def internal_notes_array
    return if internal_notes.is_a?(Array)

    errors.add(:internal_notes, "must be an array.")
  end

  def subject_phi_safe
    PhiSafeTextValidator.ensure_safe!(self, :subject, subject)
  end

  def description_phi_safe
    PhiSafeTextValidator.ensure_safe!(self, :description, description)
  end

  def guard_hbs!(actor, code, message)
    raise_support_error(code, message) unless actor&.hbs_user?
  end

  def raise_support_error(code, message)
    errors.add(:base, "[#{ERROR_CODES[code]}] #{message}")
    raise ActiveRecord::RecordInvalid, self
  end
end
