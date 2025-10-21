class CreateEncounterDiagnosisCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_diagnosis_codes do |t|
      t.references :diagnosis_code, null: false, foreign_key: true
      t.references :encounter, null: false, foreign_key: true

      t.timestamps
    end
  end
end
