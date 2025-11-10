class AddEzclaimFieldsToOrganizationSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_settings, :ezclaim_api_token, :string
    add_column :organization_settings, :ezclaim_api_url, :string, default: "https://ezclaimapiprod.azurewebsites.net/api/v2"
    add_column :organization_settings, :ezclaim_api_version, :string, default: "3.0.0"
    add_column :organization_settings, :ezclaim_enabled, :boolean, default: false
  end
end
