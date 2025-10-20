class Payment < ApplicationRecord
  audited

  belongs_to :invoice
  belongs_to :organization
  belongs_to :processed_by_user, class_name: "User", optional: true

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

  # Validations
  validates :invoice_id, :organization_id, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, :payment_status, presence: true

  # Callbacks
  after_create :update_invoice_amounts
  after_create :check_invoice_fully_paid

  private

  def update_invoice_amounts
    return unless succeeded?

    invoice.with_lock do
      invoice.amount_paid = (invoice.amount_paid + amount).round(2)
      invoice.latest_payment_at = paid_at || created_at
      invoice.save!
    end
  end

  def check_invoice_fully_paid
    return unless succeeded?

    invoice.reload
    if invoice.amount_due <= 0 && invoice.status != "paid"
      invoice.update!(status: :paid)
    elsif invoice.amount_paid > 0 && invoice.amount_paid < invoice.total && invoice.status == "issued"
      invoice.update!(status: :partially_paid)
    end
  end
end
