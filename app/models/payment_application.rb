class PaymentApplication < ApplicationRecord
  audited

  PAYMENT_SIDE_LINE_STATUS_KEYS = %w[paid adjusted partial partial_deductible].freeze
  FULLY_PAID_LINE_STATUS_KEYS = %w[paid adjusted].freeze
  LINE_STATUS_OPTIONS = [
    [ "Unpaid", "" ],
    [ "Paid", "paid" ],
    [ "Adjusted", "adjusted" ],
    [ "Partial", "partial" ],
    [ "Partial Deductible", "partial_deductible" ],
    [ "Deductible", "deductible" ],
    [ "Denied", "denied" ]
  ].freeze

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
    deductible: 4,
    partial_deductible: 5,
    partial: 6
  }, prefix: true

  validates :denial_reason, presence: true, if: -> { line_status_denied? }

  after_commit :sync_encounter_payment_status, on: [ :create, :update ]
  after_destroy_commit :sync_encounter_payment_status

  def self.payment_side_line_status_values
    PAYMENT_SIDE_LINE_STATUS_KEYS.filter_map { |key| line_statuses[key] }
  end

  def self.fully_paid_line_status_values
    FULLY_PAID_LINE_STATUS_KEYS.filter_map { |key| line_statuses[key] }
  end

  def self.display_label_for(status)
    return "Unpaid" if status.blank?
    return "Partial Deductible" if status.to_s == "partial_deductible"
    return "Partial" if status.to_s == "partial"

    status.to_s.humanize
  end

  def line_status_display_label
    self.class.display_label_for(line_status)
  end

  private

  def sync_encounter_payment_status
    encounter&.recalculate_payment_summary!
  end
end
