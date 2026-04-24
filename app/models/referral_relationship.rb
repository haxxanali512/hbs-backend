class ReferralRelationship < ApplicationRecord
  belongs_to :referral_partner
  belongs_to :referred_org, class_name: "Organization"

  has_many :referral_commissions, dependent: :destroy

  enum :status, {
    lead: 0,
    referred: 1,
    signed: 2,
    active: 3,
    ended: 4,
    ineligible: 5
  }

  enum :eligibility_status, {
    pending: 0,
    eligible: 1,
    expired: 2,
    ineligible: 3
  }, prefix: :eligibility

  validates :referral_partner_id, uniqueness: { scope: :referred_org_id }

  before_validation :set_defaults_from_referred_org
  before_validation :set_commission_window, if: -> { contract_signed_date.present? && (commission_start_date.blank? || commission_end_date.blank?) }

  def within_commission_window?(date)
    return false if commission_start_date.blank? || commission_end_date.blank?

    month = date.to_date.beginning_of_month
    month >= commission_start_date.beginning_of_month && month <= commission_end_date.end_of_month
  end

  def recalculate_totals!
    update!(
      total_revenue_to_date: referral_commissions.sum(:eligible_revenue),
      total_commission_to_date: referral_commissions.sum(:commission_amount)
    )
  end

  private

  def set_defaults_from_referred_org
    return unless referred_org

    self.referred_practice_name ||= referred_org.name
    self.tier_selected ||= referred_org.tier
  end

  def set_commission_window
    self.commission_start_date = contract_signed_date.next_month.beginning_of_month
    self.commission_end_date = commission_start_date.next_year - 1.day
  end
end
