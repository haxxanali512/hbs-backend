class CreatePrescriptionDiagnosisCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :prescription_diagnosis_codes do |t|
      t.references :prescription, null: false, foreign_key: true
      t.references :diagnosis_code, null: false, foreign_key: true
      t.timestamps
    end

    add_index :prescription_diagnosis_codes, [ :prescription_id, :diagnosis_code_id ],
              unique: true,
              name: "index_prescription_diagnosis_codes_unique"
  end
end
