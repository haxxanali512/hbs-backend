class AddMergedIntoPatientIdToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :merged_into_patient_id, :bigint
    add_index :patients, :merged_into_patient_id
    add_foreign_key :patients, :patients, column: :merged_into_patient_id
  end
end
