class CreateInsurancePlans < ActiveRecord::Migration[7.2]
  def change
    create_table :insurance_plans do |t|
      t.references :payer, null: false, foreign_key: true
      t.string :name, null: false, limit: 200
      t.integer :plan_type, null: false
      t.string :plan_code, null: false, limit: 100
      t.string :group_number_format
      t.string :member_id_format
      t.string :state_scope, array: true, default: []
      t.string :contact_url
      t.text :notes_internal
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :insurance_plans, [ :payer_id, :plan_code ], unique: true, name: "idx_insurance_plans_payer_plan_code"
    add_index :insurance_plans, :status
    add_index :insurance_plans, :plan_type
    add_index :insurance_plans, :state_scope, using: :gin
  end
end
