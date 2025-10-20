class OrganizationIdentifier < ApplicationRecord
  audited

  belongs_to :organization
end
