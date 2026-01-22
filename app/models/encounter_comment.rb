class EncounterComment < ApplicationRecord
  audited

  # =========================
  # Associations
  # =========================
  belongs_to :encounter
  belongs_to :author, class_name: "User", foreign_key: "author_user_id"
  belongs_to :organization
  belongs_to :patient
  belongs_to :provider, optional: true

  MAX_COMMENTS_PER_ENCOUNTER = 25

  # =========================
  # Enums
  # =========================
  enum :actor_type, {
    system: 0,
    hbs_admin: 1,
    hbs_user: 2,
    client_admin: 3,
    client_user: 4
  }

  enum :visibility, {
    shared_with_client: 0,
    internal_only: 1
  }

  enum :status_transition, {
    none: 0,
    additional_info_requested: 1,
    info_request_answered: 2,
    finalized: 3,
    denied: 4
  }

  enum :redaction_reason, {
    min_necessary_violation: 0,
    legal_request: 1,
    other: 2
  }

  # =========================
  # Validations
  # =========================
  validates :encounter_id, :author_user_id, :organization_id, :patient_id, :actor_type, :visibility, presence: true
  validates :body_text, presence: { message: "COMMENT_EMPTY" }, length: { minimum: 1, maximum: 2000, message: "COMMENT_TOO_LONG" }
  validates :visibility, inclusion: { in: visibilities.keys, message: "COMMENT_VISIBILITY_INVALID" }
  validates :redacted, inclusion: { in: [ true, false ] }
  validates :redaction_reason, presence: { message: "Redaction reason required" }, if: :redacted?

  validate :rate_limit_enforcement
  validate :hbs_initiation_required, on: :create
  validate :org_scope_for_clients, on: :create
  validate :redaction_reason_required_if_redacted

  # =========================
  # Scopes
  # =========================
  scope :shared, -> { where(visibility: :shared_with_client) }
  scope :internal, -> { where(visibility: :internal_only) }
  scope :not_redacted, -> { where(redacted: false) }

  # =========================
  # Callbacks
  # =========================
  before_validation :denormalize_from_encounter, on: :create
  before_validation :infer_actor_type, on: :create
  before_validation :normalize_body_text

  after_commit :apply_status_transition, on: :create

  # =========================
  # Business Logic
  # =========================
  def redact!(reason:, redacted_by:)
    update!(redacted: true, redaction_reason: reason)
  end

  def visible_to?(user)
    return false if redacted? && !user.can_redact_comment?

    # Internal comments only visible to admin users
    if internal_only?
      return user.can_view_internal_comments?
    end

    # Shared comments visible to admin users and same organization users
    if shared_with_client?
      if user.can_view_internal_comments?
        return true
      end
      # Tenant users can see shared comments from their organization
      return organization_id == user.organization_id if user.organization_id.present?
    end

    false
  end

  def status_transition_label
    status_transition.to_s.humanize
  end

  def status_transition_badge_class
    case status_transition.to_s
    when "additional_info_requested"
      "bg-orange-100 text-orange-800"
    when "info_request_answered"
      "bg-blue-100 text-blue-800"
    when "finalized"
      "bg-green-100 text-green-800"
    when "denied"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # =========================
  # Private Methods
  # =========================
  private
  def apply_status_transition
    return unless encounter && status_transition.present? && status_transition != "none"

    case status_transition
    when "additional_info_requested"
      encounter.update(shared_status: :additional_info_requested)
    when "info_request_answered"
      encounter.update(shared_status: :info_request_answered)
    when "finalized"
      encounter.update(shared_status: :finalized)
    when "denied"
      encounter.update(shared_status: :denied)
    end
  end


  def denormalize_from_encounter
    return unless encounter

    self.organization_id = encounter.organization_id
    self.patient_id = encounter.patient_id
    self.provider_id = encounter.provider_id
  end

  def infer_actor_type
    return if actor_type.present? || author.blank?

    if author.super_admin?
      self.actor_type = :hbs_admin
    elsif author.has_admin_access?
      # Check if admin or user based on role name
      if author.role&.role_name&.include?("Admin")
        self.actor_type = :hbs_admin
      else
        self.actor_type = :hbs_user
      end
    elsif author.has_tenant_access?
      # Check if client admin or user based on organization membership
      membership = author.organization_memberships.active.first
      if membership&.organization_role&.role_name&.include?("Admin")
        self.actor_type = :client_admin
      else
        self.actor_type = :client_user
      end
    end
  end

  def normalize_body_text
    return unless body_text.present?

    self.body_text = body_text.strip.gsub(/\s+/, " ")
  end

  def rate_limit_enforcement
    return unless encounter_id.present?

    existing_count = EncounterComment.where(encounter_id: encounter_id).where.not(id: id).count
    if existing_count >= MAX_COMMENTS_PER_ENCOUNTER
      errors.add(:base, "COMMENT_RATE_LIMIT_EXCEEDED")
    end
  end

  def hbs_initiation_required
    return unless encounter_id.present? && author.present?

    # Check if this is the first comment
    existing_comments = EncounterComment.where(encounter_id: encounter_id).where.not(id: id)

    if existing_comments.empty?
      # First comment must be from HBS (admin access) or System
      unless actor_type.to_s.in?([ "hbs_admin", "hbs_user", "system" ]) || author.can_view_internal_comments?
        errors.add(:base, "COMMENT_HBS_INIT_REQUIRED")
      end
    end
  end

  def org_scope_for_clients
    return unless author && encounter

    # Client users must belong to the encounter's organization
    if actor_type.to_s.in?([ "client_admin", "client_user" ])
      unless author.organization_id == encounter.organization_id
        errors.add(:base, "COMMENT_ORG_SCOPE_MISMATCH")
      end
    end
  end

  def redaction_reason_required_if_redacted
    if redacted? && redaction_reason.blank?
      errors.add(:redaction_reason, "Redaction reason is required when comment is redacted")
    end
  end

  # Prevent deletion
  def destroy
    raise ActiveRecord::RecordNotDestroyed.new("Encounters cannot be deleted. Redact instead.")
  end
end
