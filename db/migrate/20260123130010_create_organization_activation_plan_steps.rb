class CreateOrganizationActivationPlanSteps < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_activation_plan_steps do |t|
      t.references :org_accepted_plan, null: false, foreign_key: true
      t.integer :step_type, null: false
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at
      t.references :completed_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :organization_activation_plan_steps, [ :org_accepted_plan_id, :step_type ], unique: true, name: "idx_activation_plan_step_unique"
    add_index :organization_activation_plan_steps, :step_type
    add_index :organization_activation_plan_steps, :completed
  end
end
