class AddEncounterTemplateToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_reference :encounters, :encounter_template, foreign_key: true
  end
end
