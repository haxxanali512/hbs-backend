class CreateOrganizationActivationChecklists < ActiveRecord::Migration[7.2]
  def change
    create_table :activation_checklists do |t|
      t.references :organization, null: false, foreign_key: true
      t.boolean :waystar_child_account_completed, default: false, null: false
      t.boolean :ezclaim_record_completed, default: false, null: false
      t.boolean :initial_encounter_billed_completed, default: false, null: false
      t.boolean :name_match_completed, default: false, null: false

      t.timestamps
    end
  end
end
