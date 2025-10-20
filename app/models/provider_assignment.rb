class ProviderAssignment < ApplicationRecord
  belongs_to :provider
  belongs_to :organization
end
