class PayerEnrollment < ApplicationRecord
  audited

  # =========================
  # Associations
  # =========================
  belongs_to :organization
  belongs_to :payer
  belongs_to :provider, optional: true
  belongs_to :organization_location, optional: true
  has_many :documents, as: :documentable, dependent: :destroy

  # =========================
  # Enums
  # =========================
  enum :enrollment_type, {
    claims: 0,
    ERA: 1,
    EFT: 2,
    eligibility: 3,
    claim_status: 4,
    other: 5
  }

  enum :status, {
    draft: 0,
    submitted: 1,
    pending: 2,
    approved: 3,
    rejected: 4,
    cancelled: 5
  }

  # =========================
  # Validations
  # =========================
  validates :organization_id, :payer_id, :enrollment_type, presence: true
  validates :payer_id, presence: { message: "ENR_PAYER_REQUIRED" }
  validate :no_duplicate_active_enrollment
  validate :docs_required_before_submission, on: :submit
  validate :approval_only_from_clearinghouse, on: :update

  # =========================
  # Scopes
  # =========================
  scope :active, -> { where(status: [ :draft, :submitted, :pending, :approved ]) }
  scope :for_scope, ->(org_id, payer_id, enrollment_type, provider_id = nil, location_id = nil) {
    where(organization_id: org_id, payer_id: payer_id, enrollment_type: enrollment_type)
      .where(provider_id: provider_id || nil)
      .where(organization_location_id: location_id || nil)
  }

  # =========================
  # State Machine Helpers
  # =========================
  def submit!
    unless valid?(:submit)
      raise ActiveRecord::RecordInvalid.new(self)
    end
    update!(status: :submitted, submitted_at: Time.current)
  end

  def approve!(approved_at: Time.current, external_enrollment_id: nil)
    # Set external_enrollment_id if provided (from clearinghouse)
    self.external_enrollment_id = external_enrollment_id if external_enrollment_id.present?

    # Allow clearinghouse webhooks to bypass validation if external_enrollment_id is set
    if external_enrollment_id.present?
      self._skip_approval_validation = true
    end

    # Validate before updating
    unless valid?(:update)
      self._skip_approval_validation = false
      raise ActiveRecord::RecordInvalid.new(self)
    end

    update!(status: :approved, approved_at: approved_at)
  ensure
    self._skip_approval_validation = false
  end

  def reject!(rejected_at: Time.current, reason: nil)
    update!(status: :rejected, rejected_at: rejected_at, cancellation_reason: reason)
  end

  def cancel!(reason:, cancelled_by:)
    update!(status: :cancelled, cancelled_at: Time.current, cancellation_reason: reason)
  end

  def resubmit!
    increment!(:attempt_count)
    update!(status: :submitted, submitted_at: Time.current, rejected_at: nil)
  end

  # =========================
  # Business Logic
  # =========================
  def active?
    %w[draft submitted pending approved].include?(status.to_s)
  end

  def requires_documents?
    # Payer-specific logic; placeholder for now
    # Can be expanded based on payer requirements
    false
  end

  def has_required_documents?
    documents.any?
  end

  def status_badge_class
    case status.to_s
    when "draft"
      "bg-gray-100 text-gray-800"
    when "submitted"
      "bg-blue-100 text-blue-800"
    when "pending"
      "bg-yellow-100 text-yellow-800"
    when "approved"
      "bg-green-100 text-green-800"
    when "rejected"
      "bg-red-100 text-red-800"
    when "cancelled"
      "bg-gray-100 text-gray-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  # =========================
  # Private Validations
  # =========================
  private

  def no_duplicate_active_enrollment
    return unless organization_id.present? && payer_id.present? && enrollment_type.present?

    # Build query with proper nil handling
    existing = PayerEnrollment
      .where(organization_id: organization_id, payer_id: payer_id, enrollment_type: enrollment_type)
      .where(status: [ :draft, :submitted, :pending, :approved ])
      .where.not(id: id)

    # Handle optional provider_id and organization_location_id
    if provider_id.present?
      existing = existing.where(provider_id: provider_id)
    else
      existing = existing.where(provider_id: nil)
    end

    if organization_location_id.present?
      existing = existing.where(organization_location_id: organization_location_id)
    else
      existing = existing.where(organization_location_id: nil)
    end

    if existing.exists?
      errors.add(:base, "ENR_DUPLICATE_ACTIVE")
    end
  end

  def docs_required_before_submission
    # Check if status is changing to submitted
    status_changing_to_submitted = will_save_change_to_status? && status.to_s == "submitted"
    return unless status_changing_to_submitted

    # Check if documents are required and missing
    if requires_documents? && !has_required_documents?
      errors.add(:base, "ENR_DOCS_REQUIRED")
    end
  end

  def approval_only_from_clearinghouse
    # Check if status is changing to approved
    status_changing_to_approved = will_save_change_to_status? && status.to_s == "approved"
    return unless status_changing_to_approved

    # Allow if external_enrollment_id is present (from clearinghouse)
    return if external_enrollment_id.present?

    # Block manual approval attempts (unless explicitly bypassed)
    unless _skip_approval_validation
      errors.add(:status, "ENR_APPROVAL_FORBIDDEN")
    end
  end

  # Allow clearinghouse webhooks to bypass validation
  attr_accessor :_skip_approval_validation

  # Prevent deletion
  def destroy
    raise ActiveRecord::RecordNotDestroyed.new("ENR_DELETE_FORBIDDEN: Enrollments cannot be deleted; cancel instead.")
  end
end
