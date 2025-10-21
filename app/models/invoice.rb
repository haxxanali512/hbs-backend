class Invoice < ApplicationRecord
  audited

  belongs_to :organization
  belongs_to :exception_set_by_user, class_name: "User", optional: true
  has_many :invoice_line_items, dependent: :destroy
  has_many :payments, dependent: :restrict_with_error
  has_one :remit_capture, as: :capturable, dependent: :destroy
  has_many :documents, as: :documentable, dependent: :destroy

  enum :invoice_type, {
    onboarding_fee: 0,
    revenue_share_monthly: 1,
    consulting: 2,
    system_support: 3,
    adjustment: 4
  }

  enum :status, {
    draft: 0,
    issued: 1,
    partially_paid: 2,
    paid: 3,
    voided: 4
  }

  enum :exception_type, {
    none: 0,
    extension: 1,
    waiver: 2,
    suspend_hold: 3
  }, prefix: :exception

  # Validations
  validates :invoice_number, uniqueness: true, allow_nil: true
  validates :organization_id, presence: true
  validates :invoice_type, presence: true
  validates :status, presence: true
  validates :currency, presence: true
  validates :subtotal, :total, :amount_paid, :amount_credited, :amount_due,
            numericality: { greater_than_or_equal_to: 0 }
  validate :due_date_after_issue_date

  # Scopes
  scope :issued, -> { where.not(status: :draft) }
  scope :past_due, -> { where("due_date < ? AND amount_due > 0", Date.current) }
  scope :unpaid, -> { where("amount_due > 0") }
  scope :by_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_service_month, ->(month) { where(service_month: month) }
  scope :delinquent, -> { past_due.where(exception_type: [ :none, nil ]) }

  # Callbacks
  before_validation :generate_invoice_number, if: -> { issued? && invoice_number.blank? }
  before_save :recalculate_amount_due

  # Instance methods
  def calculate_amount_due
    (total - amount_paid - amount_credited).round(2)
  end

  def past_due?
    due_date.present? && due_date < Date.current && amount_due > 0
  end

  def delinquent?
    past_due? && !exception_active?
  end

  def exception_active?
    return false if exception_type.nil? || exception_none?
    return true if exception_waiver? || exception_suspend_hold?
    exception_extension? && exception_through.present? && exception_through >= Date.current
  end

  def mark_as_issued!
    return false unless draft?

    self.status = :issued
    self.issue_date ||= Date.current
    generate_invoice_number if invoice_number.blank?
    save
  end

  def apply_payment!(amount, payment_attributes = {})
    payment = payments.create!(
      organization: organization,
      amount: amount,
      payment_method: payment_attributes[:payment_method] || :manual,
      payment_provider_id: payment_attributes[:payment_provider_id],
      payment_provider_response: payment_attributes[:payment_provider_response],
      payment_status: payment_attributes[:status] || :succeeded,
      paid_at: payment_attributes[:paid_at] || Time.current,
      processed_by_user_id: payment_attributes[:processed_by_user_id],
      notes: payment_attributes[:notes]
    )

    reload
    payment
  end

  def add_line_item(attributes)
    position = invoice_line_items.maximum(:position).to_i + 1
    invoice_line_items.create!(attributes.merge(position: position))
  end

  private

  def generate_invoice_number
    return if invoice_number.present?

    # Format: INV-YYYYMM-XXXX
    year_month = (issue_date || Date.current).strftime("%Y%m")

    # Get the next sequential number for this month
    last_invoice = Invoice.where("invoice_number LIKE ?", "INV-#{year_month}-%")
                         .order(:invoice_number)
                         .last

    if last_invoice && last_invoice.invoice_number =~ /INV-#{year_month}-(\d{4})/
      sequence = $1.to_i + 1
    else
      sequence = 1
    end

    self.invoice_number = "INV-#{year_month}-#{sequence.to_s.rjust(4, '0')}"
  end

  def recalculate_amount_due
    self.amount_due = calculate_amount_due
  end

  def due_date_after_issue_date
    return if issue_date.blank? || due_date.blank?
    errors.add(:due_date, "must be after issue date") if due_date < issue_date
  end
end
