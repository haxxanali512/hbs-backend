class ReferralRelationship < ApplicationRecord
  belongs_to :referral_partner
  belongs_to :referred_org, class_name: "Organization"

  has_many :referral_commissions, dependent: :destroy

  enum :status, { lead: 0, referred: 1, signed: 2, active: 3, ended: 4, ineligible: 5 }
  enum :eligibility_status, { pending: 0, eligible: 1, expired: 2, ineligible: 3 }, prefix: :eligibility

  validates :referral_partner_id, uniqueness: { scope: :referred_org_id }

  before_validation :set_referred_practice_name, if: -> { referred_org.present? && referred_practice_name.blank? }
  before_validation :set_commission_window, if: -> { contract_signed_date.present? && (commission_start_date.blank? || commission_end_date.blank?) }

  scope :current_window, ->(date = Date.current) { where("commission_start_date <= ? AND commission_end_date >= ?", date, date) }

  def within_commission_window?(target_month)
    return false if commission_start_date.blank? || commission_end_date.blank?

    month_start = target_month.to_date.beginning_of_month
    month_end = target_month.to_date.end_of_month
    commission_start_date <= month_end && commission_end_date >= month_start
  end

  def recalculate_totals!
    update!(
      total_revenue_to_date: referral_commissions.sum(:eligible_revenue),
      total_commission_to_date: referral_commissions.sum(:commission_amount)
    )
  end

  private

  def set_referred_practice_name
    self.referred_practice_name = referred_org.name
  end

  def set_commission_window
    self.commission_start_date = contract_signed_date.next_month.beginning_of_month
    self.commission_end_date = commission_start_date.next_year - 1.day
  end
end
