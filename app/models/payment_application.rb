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
    adjusted: 3,
    deductible: 4
  }, prefix: true

  validates :denial_reason, presence: true, if: -> { line_status_denied? }

  after_commit :sync_encounter_payment_status, on: [ :create, :update ]
  after_destroy_commit :sync_encounter_payment_status

  private

  def sync_encounter_payment_status
    encounter&.recalculate_payment_summary!
  end
end
