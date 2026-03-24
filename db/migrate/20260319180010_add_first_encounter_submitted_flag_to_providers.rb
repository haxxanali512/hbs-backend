class AddFirstEncounterSubmittedFlagToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :first_encounter_submitted_notified, :boolean, null: false, default: false
  end
end

