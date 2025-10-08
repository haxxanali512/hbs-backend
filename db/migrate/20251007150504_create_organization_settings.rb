class CreateOrganizationSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_settings do |t|
      t.references :organization, null: false, foreign_key: true
      t.jsonb :feature_entitlements
      t.string :mrn_prefix
      t.string :mrn_sequence
      t.string :mrn_format
      t.string :mrn_enabled

      t.timestamps
    end
  end
end
