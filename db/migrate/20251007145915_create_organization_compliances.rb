class CreateOrganizationCompliances < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_compliances do |t|
      t.references :organization, null: false, foreign_key: true
      t.timestamp :gsa_signed_at
      t.string :gsa_envelope_id
      t.timestamp :baa_signed_at
      t.string :baa_envelope_id
      t.timestamp :phi_access_locked_at
      t.timestamp :data_retention_expires_at

      t.timestamps
    end
  end
end
