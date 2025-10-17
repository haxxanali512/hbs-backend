class AddColumnsToOrganizationCompliance < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_compliances, :privacy_policy_accepted, :boolean, default: false
    add_column :organization_compliances, :terms_of_use, :boolean, default: false
  end
end
