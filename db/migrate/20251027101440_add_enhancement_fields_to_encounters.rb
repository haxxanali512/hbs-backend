class AddEnhancementFieldsToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_reference :encounters, :organization_location, null: true, foreign_key: true
    add_reference :encounters, :appointment, null: true, foreign_key: true
    add_column :encounters, :display_status, :integer, default: 0
    add_column :encounters, :billing_insurance_status, :integer, default: 0
    add_column :encounters, :cascaded, :boolean, default: false
    add_column :encounters, :cascaded_at, :timestamp
    # Placeholder references - these will be created when actual models exist
    add_column :encounters, :claim_id, :bigint
    add_column :encounters, :patient_invoice_id, :bigint
    add_column :encounters, :eligibility_check_used_id, :bigint
    add_column :encounters, :confirmed_at, :timestamp
    add_column :encounters, :confirmed_by_id, :bigint
    add_column :encounters, :locked_for_correction, :boolean, default: false

    add_index :encounters, :claim_id
    add_index :encounters, :patient_invoice_id
    add_index :encounters, :eligibility_check_used_id
    add_index :encounters, :confirmed_by_id
    add_index :encounters, :cascaded
    add_index :encounters, :display_status
  end
end
