class ProviderSpecialty < ApplicationRecord
  belongs_to :provider
  belongs_to :specialty

  validates :provider_id, uniqueness: { scope: :specialty_id }
end
