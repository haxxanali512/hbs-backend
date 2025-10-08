class CreateOrganizationIdentifiers < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_identifiers do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :tax_identification_number
      t.string :npi
      t.integer :identifiers_change_status
      t.string :identifiers_change_docs
      t.string :previous_tin
      t.string :previous_npi
      t.timestamp :identifiers_change_effective_on

      t.timestamps
    end
  end
end
