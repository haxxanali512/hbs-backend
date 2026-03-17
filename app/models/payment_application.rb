class PaymentApplication < ApplicationRecord
  belongs_to :payment
  belongs_to :claim
  belongs_to :claim_line, optional: true
  belongs_to :patient
  belongs_to :encounter

  enum :line_status, {
    unpaid: 0,
    paid: 1,
    denied: 2,
    adjusted: 3
  }, prefix: true

  validates :denial_reason, presence: true, if: -> { line_status_denied? }
end
