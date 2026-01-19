class CreateOrgAcceptedPlanNotes < ActiveRecord::Migration[7.2]
  def change
    create_table :org_accepted_plan_notes do |t|
      t.references :org_accepted_plan, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end

    add_index :org_accepted_plan_notes, [ :org_accepted_plan_id, :created_at ]
  end
end
