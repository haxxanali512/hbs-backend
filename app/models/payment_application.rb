class PaymentApplication < ApplicationRecord
  belongs_to :payment
  belongs_to :claim
  belongs_to :claim_line, optional: true
  belongs_to :patient
  belongs_to :encounter
end
