class AddStatusTransitionToEncounterComments < ActiveRecord::Migration[7.2]
  def change
    add_column :encounter_comments, :status_transition, :integer, default: 0, null: false
    add_index :encounter_comments, :status_transition
  end
end
