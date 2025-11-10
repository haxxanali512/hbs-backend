class CreatePayerEnrollments < ActiveRecord::Migration[7.2]
  def change
    create_table :payer_enrollments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: true
      t.references :provider, foreign_key: true
      t.references :organization_location, foreign_key: true
      t.integer :enrollment_type, null: false
      t.integer :status, null: false, default: 0
      t.string :external_enrollment_id
      t.timestamp :submitted_at
      t.timestamp :approved_at
      t.timestamp :rejected_at
      t.timestamp :cancelled_at
      t.text :cancellation_reason
      t.integer :attempt_count, null: false, default: 0
      t.timestamps
    end

    # Partial unique index for active enrollments (PostgreSQL)
    add_index :payer_enrollments,
              [ :organization_id, :payer_id, :enrollment_type, :provider_id, :organization_location_id ],
              unique: true,
              name: "idx_payer_enrollments_unique_scope",
              where: "status IN (0, 1, 2, 3)"

    add_index :payer_enrollments, :external_enrollment_id
    add_index :payer_enrollments, :status
  end
end
