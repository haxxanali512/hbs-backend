class CreateClaims < ActiveRecord::Migration[7.2]
  def change
    create_table :claims do |t|
      t.string :external_claim_key
      t.references :organization, null: false, foreign_key: true
      t.references :encounter, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.references :specialty, null: false, foreign_key: true
      t.integer :status
      t.decimal :total_billed
      t.integer :total_units
      t.string :place_of_service_code
      t.timestamp :generated_at
      t.timestamp :submitted_at
      t.timestamp :accepted_at
      t.timestamp :finalized_at

      t.timestamps
    end
  end
end
