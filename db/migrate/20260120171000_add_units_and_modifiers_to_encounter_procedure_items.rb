class AddUnitsAndModifiersToEncounterProcedureItems < ActiveRecord::Migration[7.2]
  def change
    add_column :encounter_procedure_items, :units, :integer, null: false, default: 1
    add_column :encounter_procedure_items, :modifiers, :string, array: true, default: []
    add_index :encounter_procedure_items, :units
  end
end
