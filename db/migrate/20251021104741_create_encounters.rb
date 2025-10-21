class CreateEncounters < ActiveRecord::Migration[7.2]
  def change
    create_table :encounters do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.date :date_of_service
      t.references :specialty, null: false, foreign_key: true
      t.integer :billing_channel
      t.text :notes
      t.jsonb :coverage_snapshot
      t.jsonb :pricing_snapshot
      t.integer :status

      t.timestamps
    end
  end
end
