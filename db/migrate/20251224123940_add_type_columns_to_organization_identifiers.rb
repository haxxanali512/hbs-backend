class AddTypeColumnsToOrganizationIdentifiers < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_identifiers, :tax_id_type, :integer, default: nil
    add_column :organization_identifiers, :npi_type, :integer, default: nil
  end
end
