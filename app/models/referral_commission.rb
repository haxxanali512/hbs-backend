class ReferralCommission < ApplicationRecord
  belongs_to :referral_relationship

  enum :payout_status, { pending: 0, approved: 1, paid: 2, denied: 3 }

  validates :month, presence: true, uniqueness: { scope: :referral_relationship_id }
  validates :eligible_revenue, :commission_percent, :commission_amount, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_commission_amount

  delegate :referral_partner, to: :referral_relationship
  delegate :referred_org, to: :referral_relationship

  private

  def calculate_commission_amount
    return if eligible_revenue.blank? || commission_percent.blank?

    self.commission_amount = (eligible_revenue * commission_percent / 100).round(2)
  end
end
