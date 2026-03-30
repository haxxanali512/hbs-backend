class Payment < ApplicationRecord
  audited

  belongs_to :invoice, optional: true
  belongs_to :organization
  belongs_to :payer, optional: true
  belongs_to :processed_by_user, class_name: "User", optional: true
  has_many :payment_applications, dependent: :destroy

  enum :payment_method, {
    stripe: 0,
    gocardless: 1,
    manual: 2,
    check: 3,
    wire: 4
  }

  enum :payment_status, {
    pending: 0,
    succeeded: 1,
    failed: 2,
    refunded: 3
  }

  # Validations (legacy invoice payments)
  validates :invoice_id, :organization_id, presence: true, if: -> { invoice_id.present? }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: -> { amount.present? }
  validates :payment_method, :payment_status, presence: true, if: -> { invoice_id.present? }

  # Remit-based header validations (spec) – only when remit fields provided
  with_options if: -> { payer_id.present? || payment_date.present? || amount_total.present? || remit_reference.present? || source_hash.present? } do
    validates :payer_id, :payment_date, :remit_reference, :source_hash, presence: true
    validates :amount_total, numericality: { greater_than_or_equal_to: 0, message: "PAYMENT_TOTAL_INVALID" }
    validates :source_hash, uniqueness: true
    validates :remit_reference, uniqueness: { scope: [ :organization_id, :payer_id ], message: "DUPLICATE_PAYMENT" }
  end

  # Callbacks
  after_create :update_invoice_amounts
  after_create :check_invoice_fully_paid
  after_update_commit :sync_encounters_after_payment_change, if: :saved_change_to_payment_status?
  after_destroy_commit :sync_encounters_after_payment_change

  # Derived helpers for allocations
  def applied_total
    # Only payer-paid/adjusted service-line amounts should count toward "applied".
    payment_applications.select { |a| a.line_status_paid? || a.line_status_adjusted? }.sum(&:amount_applied)
  end

  def remaining_amount
    (amount_total || 0) - applied_total
  end

  def fully_applied?
    remaining_amount <= 0
  end

  def partially_applied?
    applied_total.positive? && remaining_amount.positive?
  end

  private

  def update_invoice_amounts
    return unless succeeded? && invoice.present?

    invoice.with_lock do
      invoice.amount_paid = (invoice.amount_paid + amount).round(2)
      invoice.latest_payment_at = paid_at || created_at
      invoice.save!
    end
  end

  def check_invoice_fully_paid
    return unless succeeded? && invoice.present?

    invoice.reload
    if invoice.amount_due <= 0 && invoice.status != "paid"
      invoice.update!(status: :paid)
    elsif invoice.amount_paid > 0 && invoice.amount_paid < invoice.total && invoice.status == "issued"
      invoice.update!(status: :partially_paid)
    end
  end

  def sync_encounters_after_payment_change
    payment_applications.includes(:encounter).map(&:encounter).compact.uniq.each do |encounter|
      encounter.recalculate_payment_summary!
    end
  end
end
