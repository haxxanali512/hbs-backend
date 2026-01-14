class AddAddressTypeToOrganizationLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_locations, :address_type, :integer, default: 0, null: false
    add_index :organization_locations, :address_type
    add_index :organization_locations, [ :organization_id, :address_type ]
  end
end
