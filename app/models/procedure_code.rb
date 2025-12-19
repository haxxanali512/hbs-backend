class ProcedureCode < ApplicationRecord
  audited
  include Discard::Model

  # Virtual attribute for EZClaim push flag
  attr_accessor :push_to_ezclaim

  has_many :procedure_codes_specialties, dependent: :destroy
  has_many :specialties, through: :procedure_codes_specialties
  has_many :organization_fee_schedule_items, dependent: :restrict_with_error
  has_many :claim_lines, dependent: :restrict_with_error
  has_one :procedure_code_rule, dependent: :destroy

  accepts_nested_attributes_for :procedure_code_rule, update_only: true

  enum :code_type, {
    cpt: 0,
    hcpcs: 1,
    custom: 3
  }

  enum :status, {
    active: 0,
    retired: 1
  }

  validates :code, presence: true, uniqueness: { scope: :code_type }
  validates :description, presence: true
  validates :code_type, presence: true
  validates :status, presence: true
  validate :validate_code_uniqueness

  # Callbacks
  after_create :push_to_ezclaim_if_requested

  scope :by_code_type, ->(type) { where(code_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :active, -> { where(status: "active") }
  scope :retired, -> { where(status: "retired") }
  scope :search, ->(term) { where("code ILIKE ? OR description ILIKE ?", "%#{term}%", "%#{term}%") }

  def can_be_retired?
    active? && !referenced_by_claims?
  end

  def can_be_activated?
    retired? && !referenced_by_claims?
  end

  def referenced_by_claims?
    # This would check if the code is referenced by any posted claims
    # For now, we'll return false as claims system isn't implemented yet
    false
  end

  def toggle_status!
    if active?
      retire!
    else
      activate!
    end
  end

  def code_with_description
    "#{code} - #{description}"
  end

  def code_type_badge_color
    case code_type
    when "cpt" then "bg-blue-100 text-blue-800"
    when "hcpcs" then "bg-purple-100 text-purple-800"
    when "icd10" then "bg-orange-100 text-orange-800"
    when "custom" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def status_badge_color
    case status
    when "active" then "bg-green-100 text-green-800"
    when "retired" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  # Find the active fee schedule item for a given organization
  # Returns nil if no active item exists
  def active_fee_schedule_item_for(organization)
    organization_fee_schedule_items
      .joins(:organization_fee_schedule)
      .where(organization_fee_schedules: { organization_id: organization.id })
      .where(active: true)
      .first
  end

  # Check if this procedure code has an active fee schedule item for an organization
  def has_active_fee_schedule_for?(organization)
    active_fee_schedule_item_for(organization).present?
  end

  private

  def retire!
    update!(status: "retired")
  end

  def activate!
    update!(status: "active")
  end

  def validate_code_uniqueness
    result = ProcedureCodeValidationService.validate_code_uniqueness(self)
    unless result[:valid]
      errors.add(:code, result[:error])
    end
  end

  def push_to_ezclaim_if_requested
    return unless push_to_ezclaim == true || push_to_ezclaim == "1"

    # Get the first organization with EZClaim enabled (or use a default organization)
    # Since procedure codes are global, we need to find an organization with EZClaim enabled
    organization = Organization.joins(:organization_setting)
                              .where(organization_settings: { ezclaim_enabled: true })
                              .first

    return unless organization

    begin
      service = EzclaimService.new(organization: organization)

      # Map procedure code fields to EZClaim fields
      procedure_code_data = {
        ProcCode: code,
        ProcDescription: description,
        ProcModifier: nil, # Not available in model
        ProcCharge: nil, # Not available in model
        ProcModifiersCC: nil, # Not available in model
        ProcPayFID: nil, # Not available in model
        ProcUnits: nil, # Not available in model
        ProcModifier4: nil, # Not available in model
        ProcModifier1: nil # Not available in model
      }

      result = service.create_procedure_code(procedure_code_data)

      if result[:success]
        Rails.logger.info "Procedure code #{id} successfully pushed to EZClaim"
      else
        Rails.logger.error "Failed to push procedure code #{id} to EZClaim: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Error pushing procedure code #{id} to EZClaim: #{e.message}"
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end
