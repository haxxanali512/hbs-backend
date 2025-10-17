class OrganizationBilling < ApplicationRecord
  belongs_to :organization

  enum :billing_status, {
    pending: 0,
    active: 1,
    cancelled: 2,
    pending_approval: 3
  }

  enum :provider, {
    stripe: 0,
    gocardless: 1,
    manual: 2,
    zelle: 3,
    bank_transfer: 4
  }

  # validates :last_payment_date, presence: true
  # validates :next_payment_due, presence: true
  # validates :method_last4, presence: true
  # validates :provider, presence: true

  scope :pending_approval, -> { where(billing_status: :pending_approval) }
  scope :manual_provider, -> { where(provider: :manual) }
end
