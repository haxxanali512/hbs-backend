class OrganizationContact < ApplicationRecord
  audited

  belongs_to :organization
end
