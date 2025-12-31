class Provider < ApplicationRecord
  audited
  include Discard::Model

  include AASM

  belongs_to :specialty
  belongs_to :user, optional: true
  has_many :provider_assignments, dependent: :destroy
  has_many :organizations, through: :provider_assignments
  # Documents now use Active Storage
  has_many_attached :documents
  has_many :appointments, dependent: :restrict_with_error
  has_many :encounters, dependent: :restrict_with_error
  has_many :provider_notes, dependent: :destroy
  has_many :claims, dependent: :restrict_with_error
  has_many :payer_enrollments, dependent: :restrict_with_error

  accepts_nested_attributes_for :provider_assignments, allow_destroy: true

  # Validations
  validates :first_name, :last_name, :specialty_id, :status, presence: true
  validates :first_name, :last_name, length: { minimum: 2, maximum: 100 }
  validates :npi, length: { is: 10 }
  validates :npi, uniqueness: true
  validates :license_number, length: { maximum: 50 }
  validates :license_state, length: { is: 2 }
  validates :status, inclusion: { in: %w[draft pending approved rejected suspended] }
  validate :specialty_must_be_active
  validate :specialty_must_exist
  validate :npi_format_valid
  validate :at_least_one_organization_assignment

  # Status state machinesch
  enum :status, {
    draft: "draft",
    pending: "pending",
    approved: "approved",
    rejected: "rejected",
    suspended: "suspended"
  }

  aasm column: "status", enum: true do
    state :draft, initial: true
    state :pending
    state :approved
    state :rejected
    state :suspended

    event :submit_for_approval do
      transitions from: :draft, to: :pending
      after do
        # Send notification to HBS admin
        ProviderNotificationService.notify_submission(self)
      end
    end

    event :approve do
      transitions from: :pending, to: :approved
      after do
        # Send notification to organization
        ProviderNotificationService.notify_approval(self)
      end
    end

    event :reject do
      transitions from: :pending, to: :rejected
      after do
        # Send notification to organization
        ProviderNotificationService.notify_rejection(self)
      end
    end

    event :suspend do
      transitions from: :approved, to: :suspended
      after do
        # Send notification to organization
        ProviderNotificationService.notify_suspension(self)
      end
    end

    event :reactivate do
      transitions from: :suspended, to: :approved
      after do
        # Send notification to organization
        ProviderNotificationService.notify_reactivation(self)
      end
    end

    event :resubmit do
      transitions from: :rejected, to: :pending
      after do
        # Send notification to HBS admin
        ProviderNotificationService.notify_resubmission(self)
      end
    end
  end

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_specialty, ->(specialty_id) { where(specialty_id: specialty_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_approval, -> { where(status: "pending") }
  scope :active, -> { where(status: "approved") }
  scope :search, ->(term) { where("first_name ILIKE ? OR last_name ILIKE ? OR npi ILIKE ? OR license_number ILIKE ?", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%") }

  # Callbacks
  before_validation :normalize_npi
  after_create :assign_to_organization_if_needed

  # This will be set from the controller context
  attr_accessor :assign_to_organization_id

  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name
  end

  def display_name_with_org
    if organizations.any?
      "#{full_name} (#{organizations.first.name})"
    else
      full_name
    end
  end

  def can_be_edited?
    draft? || rejected?
  end

  def can_be_submitted?
    draft? && valid?
  end

  def can_be_approved?
    pending?
  end

  def can_be_rejected?
    pending?
  end

  def can_be_suspended?
    approved?
  end

  def can_be_reactivated?
    suspended?
  end

  def can_be_resubmitted?
    rejected?
  end

  def is_active?
    approved?
  end

  def is_pending_approval?
    pending?
  end

  def status_badge_color
    case status
    when "draft" then "bg-gray-100 text-gray-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "approved" then "bg-green-100 text-green-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "suspended" then "bg-orange-100 text-orange-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  private

  def normalize_npi
    self.npi = npi&.gsub(/\D/, "") if npi.present?
  end

  def assign_to_organization_if_needed
    return unless assign_to_organization_id.present?
    return if provider_assignments.exists?(organization_id: assign_to_organization_id)

    provider_assignments.create!(organization_id: assign_to_organization_id)
  end

  def specialty_must_be_active
    return unless specialty_id.present? && specialty.present?

    unless specialty.active?
      errors.add(:specialty_id, "SPEC_RETIRED - Cannot assign a retired specialty to a provider.")
    end
  end

  def specialty_must_exist
    return unless specialty_id.present?

    unless Specialty.exists?(id: specialty_id)
      errors.add(:specialty_id, "Specialty must exist")
    end
  end

  def npi_format_valid
    return unless npi.present?

    unless npi.match?(/\A\d{10}\z/)
      errors.add(:npi, "must be exactly 10 digits")
    end
  end

  def at_least_one_organization_assignment
    return if new_record?
    nil if assign_to_organization_id.present? && provider_assignments.empty?
  end

  # Document attachment methods
  def add_document(file, document_type, description = nil)
    documents.create!(
      document_type: document_type,
      description: description,
      file: file
    )
  end

  def license_documents
    documents.where(document_type: "license")
  end

  def w9_documents
    documents.where(document_type: "w9")
  end

  def other_documents
    documents.where.not(document_type: [ "license", "w9" ])
  end

  def has_license_document?
    license_documents.exists?
  end

  def has_w9_document?
    w9_documents.exists?
  end
end
