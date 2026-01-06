class UpdatePrescriptionsForMultiplePerPatient < ActiveRecord::Migration[7.2]
  def up
    # Remove unique constraint on patient_id to allow multiple prescriptions per patient
    remove_index :prescriptions, :patient_id, if_exists: true
    add_index :prescriptions, :patient_id

    # Add new fields (nullable first to handle existing data)
    add_column :prescriptions, :organization_id, :bigint, null: true
    add_column :prescriptions, :date_written, :date, null: true
    add_column :prescriptions, :specialty_id, :bigint, null: true
    add_column :prescriptions, :procedure_code_id, :bigint, null: true
    add_column :prescriptions, :provider_id, :bigint, null: true
    add_column :prescriptions, :archived, :boolean, default: false, null: false
    add_column :prescriptions, :archived_at, :datetime, null: true

    # Set organization_id for existing prescriptions from patient's organization
    execute <<-SQL
      UPDATE prescriptions
      SET organization_id = patients.organization_id
      FROM patients
      WHERE prescriptions.patient_id = patients.id
        AND prescriptions.organization_id IS NULL
    SQL

    # Set date_written to created_at for existing prescriptions
    execute <<-SQL
      UPDATE prescriptions
      SET date_written = DATE(created_at)
      WHERE date_written IS NULL
    SQL

    # Now make organization_id and date_written required
    change_column_null :prescriptions, :organization_id, false
    change_column_null :prescriptions, :date_written, false

    # Add foreign keys
    add_foreign_key :prescriptions, :organizations
    add_foreign_key :prescriptions, :specialties
    add_foreign_key :prescriptions, :procedure_codes
    add_foreign_key :prescriptions, :providers

    # Add indexes
    add_index :prescriptions, :organization_id
    add_index :prescriptions, :specialty_id
    add_index :prescriptions, :procedure_code_id
    add_index :prescriptions, :provider_id
    add_index :prescriptions, :archived
    add_index :prescriptions, :date_written
  end

  def down
    remove_index :prescriptions, :date_written, if_exists: true
    remove_index :prescriptions, :archived, if_exists: true
    remove_index :prescriptions, :provider_id, if_exists: true
    remove_index :prescriptions, :procedure_code_id, if_exists: true
    remove_index :prescriptions, :specialty_id, if_exists: true
    remove_index :prescriptions, :organization_id, if_exists: true

    remove_foreign_key :prescriptions, :organizations, if_exists: true
    remove_foreign_key :prescriptions, :specialties, if_exists: true
    remove_foreign_key :prescriptions, :procedure_codes, if_exists: true
    remove_foreign_key :prescriptions, :providers, if_exists: true

    remove_column :prescriptions, :archived_at, if_exists: true
    remove_column :prescriptions, :archived, if_exists: true
    remove_column :prescriptions, :provider_id, if_exists: true
    remove_column :prescriptions, :procedure_code_id, if_exists: true
    remove_column :prescriptions, :specialty_id, if_exists: true
    remove_column :prescriptions, :date_written, if_exists: true
    remove_column :prescriptions, :organization_id, if_exists: true

    remove_index :prescriptions, :patient_id, if_exists: true
    add_index :prescriptions, :patient_id, unique: true
  end
end
