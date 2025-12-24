class OrganizationIdentifier < ApplicationRecord
  audited

  belongs_to :organization

  enum :tax_id_type, {
    ssn: 0,
    ein: 1
  }

  enum :npi_type, {
    type_1: 0,
    type_2: 1
  }
end
