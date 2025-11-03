class ClaimGenPayerRoute < ApplicationRecord
  belongs_to :organization
  belongs_to :payer

  validates :claimgen_account_key, presence: true
  validates :external_payer_code, presence: true, allow_blank: true
  validates :organization_id, uniqueness: { scope: [ :payer_id, :claimgen_account_key ] }
end


# ClaimGenPayerRoute this model is for external payer routes that are used to submit claims to the external system.
