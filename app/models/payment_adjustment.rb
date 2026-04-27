class PaymentAdjustment < ApplicationRecord
  audited

  belongs_to :payment

  enum :adjustment_type, {
    increase: 0,
    decrease: 1
  }

  validates :adjustment_type, :adjustment_date, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validate :net_payment_cannot_be_negative

  def signed_amount
    return amount.to_d if increase?
    return -amount.to_d if decrease?

    0.to_d
  end

  def display_amount
    signed_amount
  end

  private

  def net_payment_cannot_be_negative
    return if payment.blank?

    remaining_adjustments_total =
      payment.payment_adjustments.reject { |adjustment| adjustment.id == id }.sum(&:signed_amount)
    projected_total = payment.base_applied_total + remaining_adjustments_total + signed_amount

    if projected_total.negative?
      errors.add(:amount, "would reduce the final net payment below zero")
    end
  end
end
