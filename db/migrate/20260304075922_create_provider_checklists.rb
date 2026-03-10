class CreateProviderChecklists < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_checklists do |t|
      t.references :provider, null: false, foreign_key: true
      t.boolean :easyclaim_profile_created
      t.boolean :waystar_name_match_confirmed
      t.boolean :npi_verified
      t.boolean :taxonomy_verified

      t.timestamps
    end
  end
end
