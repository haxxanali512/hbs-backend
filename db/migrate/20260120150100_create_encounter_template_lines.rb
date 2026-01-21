class CreateEncounterTemplateLines < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_template_lines do |t|
      t.references :encounter_template, null: false, foreign_key: true
      t.references :procedure_code, null: false, foreign_key: true
      t.integer :units, null: false, default: 1
      t.string :modifiers, array: true, default: []
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :encounter_template_lines, [ :encounter_template_id, :procedure_code_id ], unique: true, name: "index_enc_template_lines_unique"
    add_index :encounter_template_lines, [ :encounter_template_id, :position ]
  end
end
