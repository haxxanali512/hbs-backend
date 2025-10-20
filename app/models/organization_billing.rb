class OrganizationBilling < ApplicationRecord
  audited

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

  # after_create_commit :update_organization_activation_status
  # after_update_commit :advance_activation_status_if_ready

  # def update_organization_activation_status
  #   organization.update!(activation_status: :billing_setup)
  # end

  # def advance_activation_status_if_ready
  #   return unless saved_change_to_billing_status?

  #   if active? && organization.billing_setup?
  #     organization.sign_documents!
  #   end
  # end

  # validates :last_payment_date, presence: true
  # validates :next_payment_due, presence: true
  # validates :method_last4, presence: true
  # validates :provider, presence: true

  scope :pending_approval, -> { where(billing_status: :pending_approval) }
  scope :manual_provider, -> { where(provider: :manual) }
end
