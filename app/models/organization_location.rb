class OrganizationLocation < ApplicationRecord
  audited
  include Discard::Model

  belongs_to :organization
  has_many :encounters, dependent: :restrict_with_error
  has_many :appointments, dependent: :restrict_with_error
  has_many :payer_enrollments, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :status, presence: true, inclusion: { in: %w[active inactive retired] }
  validates :place_of_service_code, presence: true, length: { is: 2 }
  validates :billing_npi, length: { is: 10 }, allow_blank: true
  validates :billing_npi, uniqueness: { scope: :organization_id }, allow_blank: true

  # Custom validations
  validate :unique_name_per_organization
  validate :soft_duplicate_guard
  validate :billing_npi_checksum
  validate :address_required_unless_virtual_or_telehealth
  validate :one_remittance_address_per_organization
  validate :can_be_retired

  # Enums
  enum :status, {
    active: 0,
    inactive: 1,
    retired: 2
  }

  enum :address_type, {
    servicing: 0,
    billing: 1,
    remittance: 2
  }

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :inactive, -> { where(status: :inactive) }
  scope :retired, -> { where(status: :retired) }
  scope :available_for_encounters, -> { where(status: [ :active ]) }
  scope :by_organization, ->(org) { where(organization: org) }
  scope :servicing, -> { where(address_type: :servicing) }
  scope :billing, -> { where(address_type: :billing) }
  scope :remittance, -> { where(address_type: :remittance) }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  # State machine methods
  def can_be_activated?
    inactive? && address_rule_satisfied?
  end

  def can_be_inactivated?
    active?
  end

  def can_be_reactivated?
    inactive?
  end

  def can_be_retired?
    active? || inactive?
  end

  def activate!
    return false unless can_be_activated?
    update!(status: :active)
  end

  def inactivate!
    return false unless can_be_inactivated?
    update!(status: :inactive)
  end

  def reactivate!
    return false unless can_be_reactivated?
    update!(status: :active)
  end

  def retire!
    return false unless can_be_retired?
    update!(status: :retired)
  end

  def status_badge_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "inactive" then "bg-yellow-100 text-yellow-800"
    when "retired" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def display_name
    "#{name} (#{organization.name})"
  end

  def has_open_encounters?
    encounters.joins(:claims).where(claims: { status: [ "draft", "submitted", "pending" ] }).exists?
  end

  private

  def unique_name_per_organization
    existing = OrganizationLocation.kept.where(organization: organization, name: name)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:name, "must be unique within organization")
    end
  end

  def soft_duplicate_guard
    return if is_virtual? || address_line_1.blank?

    normalized_address = normalize_address(address_line_1)
    existing = OrganizationLocation.kept.where(
      organization: organization,
      place_of_service_code: place_of_service_code
    ).where.not(id: id)

    existing.each do |location|
      if normalize_address(location.address_line_1) == normalized_address
        errors.add(:base, "A similar location already exists with the same address and place of service code")
        break
      end
    end
  end

  def billing_npi_checksum
    return if billing_npi.blank?

    unless valid_npi_checksum?(billing_npi)
      errors.add(:billing_npi, "has invalid checksum")
    end
  end

  def address_required_unless_virtual_or_telehealth
    return if is_virtual? || %w[02 10].include?(place_of_service_code)

    if address_line_1.blank?
      errors.add(:address_line_1, "is required for this place of service code")
    end
  end

  def one_remittance_address_per_organization
    return unless remittance?

    existing = OrganizationLocation.kept
                                   .where(organization: organization, address_type: :remittance)
                                   .where.not(id: id)

    if existing.exists?
      errors.add(:address_type, "An organization can only have one remittance address")
    end
  end

  def can_be_retired
    if status == "retired" && has_open_encounters?
      errors.add(:base, "Cannot retire location with open encounters or claims")
    end
  end

  def address_rule_satisfied?
    is_virtual? || %w[02 10].include?(place_of_service_code) || address_line_1.present?
  end

  def normalize_address(addr)
    addr.to_s.downcase.gsub(/[^\w\s]/, "").gsub(/\s+/, " ").strip
  end

  def valid_npi_checksum?(npi)
    return false unless npi.match?(/\A\d{10}\z/)

    # NPI checksum algorithm
    digits = npi.chars.map(&:to_i)
    sum = 0

    digits.each_with_index do |digit, index|
      if index.even?
        sum += digit * 2
        sum += digit if digit > 4
      else
        sum += digit
      end
    end

    sum % 10 == 0
  end
end
