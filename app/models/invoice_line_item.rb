class InvoiceLineItem < ApplicationRecord
  audited
  belongs_to :invoice

  # Validations
  validates :invoice_id, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :percent_applied, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true

  # Scopes
  scope :ordered, -> { order(:position) }

  # Default scope
  default_scope { order(:position) }
end
