class CreateEncounterProcedureItems < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_procedure_items do |t|
      t.references :encounter, null: false, foreign_key: true
      t.references :procedure_code, null: false, foreign_key: true
      t.boolean :is_primary, default: false, null: false

      t.timestamps
    end

    add_index :encounter_procedure_items, [ :encounter_id, :procedure_code_id ], unique: true, name: 'index_encounter_procedure_items_unique'
    add_index :encounter_procedure_items, :is_primary
  end
end
