class OrganizationFeeSchedule < ApplicationRecord
  audited
  include Discard::Model

  belongs_to :organization
  belongs_to :provider, optional: true
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
  validate :provider_belongs_to_organization
  validate :unique_schedule_per_provider

  scope :org_wide, -> { where(provider_id: nil) }
  scope :provider_specific, -> { where.not(provider_id: nil) }
  scope :unlocked, -> { where(locked: false) }
  scope :locked, -> { where(locked: true) }

  def org_wide?
    provider_id.nil?
  end

  def provider_specific?
    provider_id.present?
  end

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

  private

  def provider_belongs_to_organization
    return unless provider_id.present?

    unless organization.providers.exists?(provider_id)
      errors.add(:provider, "must belong to the organization")
    end
  end

  def unique_schedule_per_provider
    return unless organization_id.present?

    existing = OrganizationFeeSchedule.where(organization_id: organization_id, provider_id: provider_id)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      if provider_id.present?
        errors.add(:provider, "already has a fee schedule for this organization")
      else
        errors.add(:organization, "already has an organization-wide fee schedule")
      end
    end
  end
end
