class RemoveOrganizationIdFromProviders < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :providers, :organizations
    remove_index :providers, :organization_id
    remove_column :providers, :organization_id, :bigint
  end
end
