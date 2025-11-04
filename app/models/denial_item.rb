class DenialItem < ApplicationRecord
  audited

  belongs_to :denial
  belongs_to :claim_line

  validates :amount_denied, numericality: { greater_than_or_equal_to: 0 }
  validates :carc_codes, presence: true
end
