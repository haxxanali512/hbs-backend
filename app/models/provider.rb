class Provider < ApplicationRecord
  audited
  include Discard::Model

  include AASM

  has_many :provider_specialties, dependent: :destroy
  has_many :specialties, through: :provider_specialties
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
  accepts_nested_attributes_for :provider_specialties, allow_destroy: true

  # Validations
  validates :first_name, :last_name, :status, presence: true
  validates :first_name, :last_name, length: { minimum: 2, maximum: 100 }
  validates :npi, length: { is: 10 }, allow_nil: true
  validates :npi, uniqueness: true, allow_nil: true
  validates :license_number, length: { maximum: 50 }
  validates :license_state, length: { is: 2 }
  validates :status, inclusion: { in: %w[drafted pending approved deactivated] }
  validate :at_least_one_specialty
  validate :specialties_must_be_active
  validate :npi_format_valid
  validate :at_least_one_organization_assignment

  # Status enum
  enum :status, {
    drafted: "drafted",
    pending: "pending",
    approved: "approved",
    deactivated: "deactivated"
  }

  aasm column: "status", enum: true do
    state :drafted, initial: true
    state :pending
    state :approved
    state :deactivated

    event :submit_for_approval do
      transitions from: :drafted, to: :pending
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

    event :deactivate do
      transitions from: [ :approved, :pending ], to: :deactivated
      after do
        # Send notification to organization
        ProviderNotificationService.notify_deactivation(self)
      end
    end

    event :reactivate do
      transitions from: :deactivated, to: :pending
      after do
        # Send notification to HBS admin
        ProviderNotificationService.notify_resubmission(self)
      end
    end
  end

  # Scopes
  scope :by_status, ->(status) { where(status: status) }
  scope :by_specialty, ->(specialty_id) { joins(:specialties).where(specialties: { id: specialty_id }) }
  scope :recent, -> { order(created_at: :desc) }
  scope :pending_approval, -> { where(status: "pending") }
  scope :active, -> { where(status: "approved") }
  scope :search, ->(term) { where("first_name ILIKE ? OR last_name ILIKE ? OR npi ILIKE ? OR license_number ILIKE ?", "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%") }

  # Callbacks
  before_validation :normalize_npi
  after_create :assign_to_organization_if_needed
  after_create :create_support_ticket_for_hbs

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
    drafted? || deactivated?
  end

  def can_be_submitted?
    drafted? && valid?
  end

  def can_be_approved?
    pending?
  end

  def can_be_deactivated?
    approved? || pending?
  end

  def can_be_reactivated?
    deactivated?
  end

  def is_active?
    approved?
  end

  def is_pending_approval?
    pending?
  end

  def can_be_added_to_claims?
    approved?
  end

  def can_be_added_to_encounters?
    pending? || approved?
  end

  def status_badge_color
    case status
    when "drafted" then "bg-gray-100 text-gray-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "approved" then "bg-green-100 text-green-800"
    when "deactivated" then "bg-red-100 text-red-800"
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

  def at_least_one_specialty
    if provider_specialties.empty? && (new_record? || provider_specialties.reload.empty?)
      errors.add(:base, "At least one specialty must be selected")
    end
  end

  def specialties_must_be_active
    provider_specialties.each do |ps|
      next unless ps.specialty.present?
      unless ps.specialty.active?
        errors.add(:base, "SPEC_RETIRED - Cannot assign a retired specialty (#{ps.specialty.name}) to a provider.")
      end
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
    # W9 documents are stored via Active Storage
    # Return attachments that are images (W9 uploads)
    documents.attachments.select { |att| att.content_type&.start_with?("image/") }
  end

  def other_documents
    documents.where.not(document_type: [ "license", "w9" ])
  end

  def has_license_document?
    license_documents.exists?
  end

  def has_w9_document?
    w9_documents.any?
  end

  def create_support_ticket_for_hbs
    return unless organizations.any?

    organization = organizations.first
    return unless organization.present?

    # Find an HBS user to create the ticket
    hbs_user = User.where(role: Role.find_by(role_name: "super_admin")).first
    return unless hbs_user.present?

    SupportTicket.create!(
      organization: organization,
      created_by_user: organization.owner || hbs_user,
      category: :general_question,
      priority: :normal,
      subject: "New Provider Added: #{full_name}",
      description: "A new provider (#{full_name}, NPI: #{npi || 'N/A'}) has been added and requires review and addition to external systems (Waystar).",
      linked_resource_type: "Provider",
      linked_resource_id: id.to_s
    )
  rescue => e
    Rails.logger.error("Failed to create support ticket for provider #{id}: #{e.message}")
  end
end
