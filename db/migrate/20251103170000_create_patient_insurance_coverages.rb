class CreatePatientInsuranceCoverages < ActiveRecord::Migration[7.2]
  def change
    create_table :patient_insurance_coverages do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: true
      t.references :insurance_plan, null: false, foreign_key: true
      t.string :member_id, null: false, limit: 30
      t.string :subscriber_name, null: false, limit: 200
      t.jsonb :subscriber_address, null: false, default: {}
      t.integer :relationship_to_subscriber, null: false
      t.integer :coverage_order, null: false, default: 0
      t.date :effective_date
      t.date :termination_date
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :patient_insurance_coverages, [ :patient_id, :insurance_plan_id, :member_id ], unique: true, name: "idx_coverage_patient_plan_member"
    add_index :patient_insurance_coverages, [ :organization_id, :patient_id ]
    add_index :patient_insurance_coverages, :status
    add_index :patient_insurance_coverages, :coverage_order
    add_index :patient_insurance_coverages, [ :patient_id, :status, :coverage_order ]
  end
end
