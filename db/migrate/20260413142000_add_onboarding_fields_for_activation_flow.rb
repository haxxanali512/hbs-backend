class AddOnboardingFieldsForActivationFlow < ActiveRecord::Migration[7.2]
  def change
    add_column :organizations, :referral_code, :string

    add_column :organization_compliances, :contract_accepted_at, :datetime
    add_column :organization_compliances, :contract_version, :string
  end
end
