class Specialty < ApplicationRecord
  audited
  include Discard::Model

  has_many :procedure_codes_specialties, dependent: :destroy
  has_many :procedure_codes, through: :procedure_codes_specialties
  has_many :provider_specialties, dependent: :destroy
  has_many :providers, through: :provider_specialties
  has_many :appointments, dependent: :restrict_with_error
  has_many :encounters, dependent: :restrict_with_error
  has_many :claims, dependent: :restrict_with_error
  has_many :organization_fee_schedule_specialties, dependent: :destroy
  has_many :organization_fee_schedules, through: :organization_fee_schedule_specialties

  enum status: { active: 0, retired: 1 }

  validates :name, presence: true, uniqueness: {
    case_sensitive: false,
    message: "SPEC_NAME_DUPLICATE - Specialty name must be unique."
  }
  validates :status, presence: true
  validates :description, presence: true

  scope :active, -> { where(status: :active) }
  scope :retired, -> { where(status: :retired) }
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :search, ->(term) { where("name ILIKE ? OR description ILIKE ?", "%#{term}%", "%#{term}%") }

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "status", "description" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "procedure_codes", "providers" ]
  end

  # Instance methods
  def display_name
    name
  end

  def can_be_retired?
    active? && providers.empty?
  end

  def can_be_edited?
    active?
  end

  def can_be_deleted?
    providers.empty?
  end

  def provider_count
    providers.count
  end

  def procedure_code_count
    procedure_codes.count
  end

  def impact_analysis
    {
      total_providers: provider_count,
      providers: providers.includes(:organizations).map do |provider|
        {
          id: provider.id,
          name: provider.full_name,
          organization: provider.organizations.first&.name || "No Organization",
          organization_id: provider.organizations.first&.id
        }
      end
    }
  end

  def allowed_cpt_codes
    procedure_codes.pluck(:code, :description).map { |code, desc| "#{code} - #{desc}" }
  end

  def allows_cpt_code?(code)
    procedure_codes.exists?(code: code)
  end

  # Validation methods for business rules
  def validate_provider_assignment(provider)
    return true if active?

    errors.add(:base, "SPEC_RETIRED - Cannot assign a retired specialty to a provider.")
    false
  end

  def validate_cpt_code_allowed(code)
    return true if allows_cpt_code?(code)

    errors.add(:base, "SPEC_CPT_NOT_ALLOWED - Procedure not permitted under this specialty.")
    false
  end

  # Callbacks
  before_destroy :check_provider_dependencies

  private

  def check_provider_dependencies
    if providers.any?
      errors.add(:base, "Cannot delete specialty with assigned providers.")
      throw(:abort)
    end
  end
end
