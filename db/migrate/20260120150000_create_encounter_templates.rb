class CreateEncounterTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :encounter_templates do |t|
      t.string :name, null: false
      t.references :specialty, null: false, foreign_key: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :encounter_templates, [ :specialty_id, :name ], unique: true
    add_index :encounter_templates, :active
  end
end
