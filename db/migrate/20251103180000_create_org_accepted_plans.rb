class CreateOrgAcceptedPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :org_accepted_plans do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :insurance_plan, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :network_type, null: false
      t.integer :enrollment_status, null: false, default: 0
      t.date :effective_date, null: false
      t.date :end_date
      t.references :added_by, null: false, foreign_key: { to_table: :users }
      t.text :notes
      t.timestamps
    end

    add_index :org_accepted_plans, [ :organization_id, :insurance_plan_id ], unique: true, name: "idx_org_accepted_plan_unique"
    add_index :org_accepted_plans, :status
    add_index :org_accepted_plans, :network_type
    add_index :org_accepted_plans, :enrollment_status
    add_index :org_accepted_plans, [ :organization_id, :status ]
  end
end
