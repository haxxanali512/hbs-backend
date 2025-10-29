class CreateAppointments < ActiveRecord::Migration[7.2]
  def change
    create_table :appointments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :organization_location, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :specialty, null: false, foreign_key: true
      t.integer :appointment_type
      t.integer :status
      t.timestamp :scheduled_start_at
      t.timestamp :scheduled_end_at
      t.timestamp :actual_start_at
      t.timestamp :actual_end_at
      t.integer :duration_minutes
      t.text :reason_for_visit
      t.text :notes
      t.timestamp :discarded_at

      t.timestamps
    end
  end
end
