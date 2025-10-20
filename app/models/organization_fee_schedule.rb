class OrganizationFeeSchedule < ApplicationRecord
  audited

  belongs_to :organization
  belongs_to :provider
end
