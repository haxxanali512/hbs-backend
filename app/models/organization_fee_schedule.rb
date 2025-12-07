class OrganizationFeeSchedule < ApplicationRecord
  audited
  include Discard::Model

  belongs_to :organization
  belongs_to :specialty, optional: true
  has_many :organization_fee_schedule_items, dependent: :destroy
  has_many :procedure_codes, through: :organization_fee_schedule_items

  enum :currency, {
    usd: 0,
    eur: 1,
    gbp: 2,
    cad: 3
  }

  validates :name, presence: true
  validates :currency, presence: true
  validates :organization_id, presence: true
  validate :unique_schedule_per_organization

  scope :unlocked, -> { where(locked: false) }
  scope :locked, -> { where(locked: true) }

  def can_be_edited?
    !locked?
  end

  def can_be_locked?
    !locked?
  end

  def can_be_unlocked?
    locked?
  end

  def active_items
    organization_fee_schedule_items.where(active: true)
  end

  def locked_items
    organization_fee_schedule_items.where(locked: true)
  end

  def unlock_all_items!
    organization_fee_schedule_items.update_all(locked: false)
  end

  def lock_all_items!
    organization_fee_schedule_items.update_all(locked: true)
  end

  # Class method to get or create fee schedule for an organization
  def self.get_or_create_for_organization(organization, specialty = nil)
    fee_schedule = organization.organization_fee_schedules.kept.first

    if fee_schedule.nil?
      fee_schedule = organization.organization_fee_schedules.create!(
        name: "#{organization.name} Fee Schedule",
        currency: :usd,
        specialty_id: specialty&.id
      )
    end

    fee_schedule
  end

  private

  def unique_schedule_per_organization
    return unless organization_id.present?

    existing = OrganizationFeeSchedule.kept.where(organization_id: organization_id)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:organization, "already has a fee schedule")
    end
  end
end
