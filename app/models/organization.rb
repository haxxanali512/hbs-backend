class Organization < ApplicationRecord
  audited
  include Discard::Model

  include AASM

  # Flow: pending → compliance_setup → billing_setup → terms_agreement → activated
  enum :activation_status, {
    pending: 0,
    compliance_setup: 1,
    billing_setup: 2,
    terms_agreement: 3,
    activated: 4
  }

  aasm column: "activation_status", enum: true do
    state :pending, initial: true
    state :compliance_setup
    state :billing_setup
    state :terms_agreement
    state :activated

    event :compliance_setup_complete do
      transitions from: :pending, to: :compliance_setup
    end

    event :billing_setup_complete do
      transitions from: :compliance_setup, to: :billing_setup
    end

    event :terms_agreement_complete do
      transitions from: :billing_setup, to: :terms_agreement
    end

    event :activate do
      # Admin override: can activate directly from pending (skip all steps)
      # Normal user flow: activate from terms_agreement (last step completed)
      transitions from: [ :pending, :terms_agreement ], to: :activated
    end
  end

  belongs_to :owner, class_name: "User", foreign_key: "owner_id"
  has_many :organization_memberships, dependent: :destroy
  has_many :members, through: :organization_memberships, source: :user
  has_one :organization_billing, dependent: :destroy
  has_one :organization_compliance, dependent: :destroy
  has_one :organization_contact, dependent: :destroy
  has_one :organization_identifier, dependent: :destroy
  has_one :organization_setting, dependent: :destroy
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :provider_assignments, dependent: :destroy
  has_many :providers, through: :provider_assignments
  has_many :documents, as: :documentable, dependent: :destroy
  has_many :organization_fee_schedules, dependent: :destroy
  has_many :organization_locations, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :encounters, dependent: :restrict_with_error
  has_many :claims, dependent: :restrict_with_error
  has_many :patients, dependent: :destroy
  has_many :patient_insurance_coverages, dependent: :restrict_with_error
  has_many :org_accepted_plans, dependent: :restrict_with_error
  has_many :payer_enrollments, dependent: :restrict_with_error
  has_many :support_tickets, dependent: :destroy
  has_many :notifications, dependent: :destroy
  after_create :invite_owner
  after_create :create_default_settings

  accepts_nested_attributes_for :organization_setting, update_only: true

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true
  validates :owner, presence: true
  validates :tier, presence: true
  validate :tier_value_valid

  # Parsed numeric tier percentage, e.g. "6%", "6.0", 6 -> 6.0
  def tier_percentage
    return nil unless tier.present?
    str = tier.to_s.strip
    str = str.delete("%")
    Float(str)
  rescue ArgumentError
    nil
  end

  def tier_value_valid
    value = tier_percentage
    unless value&.in?([ 6.0, 7.0, 8.0, 9.0 ])
      errors.add(:tier, "must be one of 6, 7, 8, or 9 percent")
    end
  end

  def activation_progress_percentage
    case activation_status
    when "pending" then 0
    when "compliance_setup" then 25
    when "billing_setup" then 50
    when "terms_agreement" then 75
    when "activated" then 100
    else 0
    end
  end

  def next_activation_step
    case activation_status
    when "pending" then "compliance_setup"
    when "compliance_setup" then "billing_setup"
    when "billing_setup" then "terms_agreement"
    when "terms_agreement" then "activated"
    else nil
    end
  end

  def can_proceed_to_step?(step)
    case step
    when "compliance_setup" then pending?
    when "billing_setup" then compliance_setup?
    when "terms_agreement" then billing_setup?
    when "activated" then terms_agreement?
    else false
    end
  end

  def activated?
    activation_status == "activated"
  end

  def active_members
    members.where(organization_memberships: { active: true })
  end

  def add_member(user, role = nil)
    organization_memberships.create!(user: user, organization_role: role, active: true)
  end

  # Find the active fee schedule item for a given procedure code
  # Returns nil if no active item exists
  def fee_schedule_item_for(procedure_code)
    OrganizationFeeScheduleItem.joins(:organization_fee_schedule)
                              .where(organization_fee_schedules: { organization_id: id })
                              .where(procedure_code_id: procedure_code.id)
                              .where(active: true)
                              .first
  end

  # Check if a procedure code has an active fee schedule item
  def has_fee_schedule_for?(procedure_code)
    fee_schedule_item_for(procedure_code).present?
  end

  # Get or create the organization's fee schedule
  def get_or_create_fee_schedule(specialty = nil)
    OrganizationFeeSchedule.get_or_create_for_organization(self, specialty)
  end

  # Get all procedure codes unlocked for this organization
  # Based on active fee schedule items for this org
  def unlocked_procedure_codes
    ProcedureCode.joins(organization_fee_schedule_items: :organization_fee_schedule)
                 .where(organization_fee_schedules: { organization_id: id })
                 .where(organization_fee_schedule_items: { active: true })
                 .distinct
  end

  # Check if a specific procedure code is unlocked for this organization
  def procedure_code_unlocked?(procedure_code_id)
    organization_fee_schedule_items
      .joins(:organization_fee_schedule)
      .where(organization_fee_schedules: { organization_id: id })
      .where(procedure_code_id: procedure_code_id, active: true)
      .exists?
  end

  # Get all specialties that unlocked a specific procedure code for this organization
  def specialties_for_procedure_code(procedure_code_id)
    Specialty.joins(
      providers: { provider_assignments: :organization }
    ).joins(
      "INNER JOIN procedure_codes_specialties ON procedure_codes_specialties.specialty_id = specialties.id"
    ).where(
      provider_assignments: { organization_id: id, active: true },
      providers: { status: "approved" },
      specialties: { status: :active },
      procedure_codes_specialties: { procedure_code_id: procedure_code_id }
    ).distinct
  end

  def invite_owner
    return if owner.nil?
    return if owner.invitation_sent_at.present? # Already invited

    # Skip email sending if mailer is not configured (e.g., during seeding)
    begin
      owner.invite!
    rescue => e
      # Log error but don't fail if it's a mail delivery issue
      if e.message.include?("Connection refused") || e.message.include?("SMTP")
        Rails.logger.warn("Could not send owner invitation email: #{e.message}")
      else
        raise
      end
    end
  end

  def create_default_settings
    create_organization_setting unless organization_setting.present?
  end

  def remove_member(user)
    membership = organization_memberships.find_by(user: user)
    membership&.deactivate!
  end

  # ===========================================================
  # POST-ACTIVATION RESOURCE VALIDATION
  # ===========================================================

  def has_active_providers?
    providers.active.any?
  end

  def has_fee_schedules?
    organization_fee_schedules.kept.any?
  end

  def has_active_specialties?
    # Check if any providers have active specialties
    providers.joins(:specialty).where(specialties: { status: :active }).any?
  end

  def has_accepted_plans?
    # Placeholder - will be implemented when AcceptedPlan model exists
    # For now, return true as this is insurance-specific
    true
  end

  def has_locations?
    organization_locations.active.any?
  end

  def missing_critical_resources
    missing = []
    missing << "Providers" unless has_active_providers?
    missing << "Fee Schedules" unless has_fee_schedules?
    missing << "Specialties" unless has_active_specialties?
    missing << "Locations" unless has_locations?
    missing
  end

  def has_missing_critical_resources?
    missing_critical_resources.any?
  end

  def critical_resources_complete?
    !has_missing_critical_resources?
  end

  # Resource status summary
  def resource_status_summary
    {
      providers: { present: has_active_providers?, count: providers.active.count },
      fee_schedules: { present: has_fee_schedules?, count: organization_fee_schedules.kept.count },
      specialties: { present: has_active_specialties?, count: providers.joins(:specialty).where(specialties: { status: :active }).distinct.count(:specialty_id) },
      locations: { present: has_locations?, count: organization_locations.active.count },
      accepted_plans: { present: has_accepted_plans?, count: 0 } # Placeholder
    }
  end
end
