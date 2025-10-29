class UpdateDiagnosisCodesAddIndexes < ActiveRecord::Migration[7.2]
  def up
    # Add index for code uniqueness and performance
    add_index :diagnosis_codes, :code, unique: true, name: 'index_diagnosis_codes_on_code'

    # Add index for status queries
    add_index :diagnosis_codes, :status, name: 'index_diagnosis_codes_on_status'

    # Backfill existing records with active status
    DiagnosisCode.where(status: nil).update_all(status: :active)

    # Change status column to not null if we want strict enforcement
    # For now, keeping it nullable for backward compatibility during migration
  end

  def down
    remove_index :diagnosis_codes, :code, name: 'index_diagnosis_codes_on_code'
    remove_index :diagnosis_codes, :status, name: 'index_diagnosis_codes_on_status'
  end
end
