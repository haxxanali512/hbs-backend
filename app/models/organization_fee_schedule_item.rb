class OrganizationFeeScheduleItem < ApplicationRecord
  audited except: [ :unit_price ]
  include Discard::Model


  belongs_to :organization_fee_schedule
  belongs_to :procedure_code

  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :pricing_rule, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :locked, inclusion: { in: [ true, false ] }
  validate :unique_active_item_per_schedule_and_procedure
  validate :pricing_rule_compatible_with_procedure

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :unlocked, -> { where(locked: false) }
  scope :locked, -> { where(locked: true) }

  def can_be_edited?
    !locked? && !referenced_by_claims?
  end

  def can_be_deleted?
    !referenced_by_claims?
  end

  def can_be_activated?
    !active? && !locked?
  end

  def can_be_deactivated?
    active? && !locked?
  end

  def can_be_locked?
    !locked?
  end

  def can_be_unlocked?
    locked?
  end

  def referenced_by_claims?
    # This would check if the item is referenced by any posted claims
    # For now, we'll return false as claims system isn't implemented yet
    false
  end

  def pricing_snapshot
    {
      procedure_code_id: procedure_code_id,
      pricing_rule: pricing_rule,
      unit_price: unit_price,
      currency: organization_fee_schedule.currency,
      source_schedule_id: organization_fee_schedule_id,
      source_item_id: id,
      snapshot_at: Time.current
    }
  end

  private

  def unique_active_item_per_schedule_and_procedure
    return unless active?
    byebug

    existing = OrganizationFeeScheduleItem.where(
      organization_fee_schedule: organization_fee_schedule,
      procedure_code: procedure_code,
      active: true
    )
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:procedure_code, "FEE_DUP_ITEM - Duplicate fee for this code (provider scope).")
    end
  end

  def pricing_rule_compatible_with_procedure
    return unless pricing_rule.present? && procedure_code.present?

    # This would validate against CPT Rule matrix
    # For now, we'll accept common pricing rules
    valid_rules = %w[per_unit per_minute per_hour per_visit per_procedure]

    unless valid_rules.include?(pricing_rule)
      errors.add(:pricing_rule, "FEE_RULE_INVALID - Pricing rule not allowed for this CPT.")
    end
  end
end
