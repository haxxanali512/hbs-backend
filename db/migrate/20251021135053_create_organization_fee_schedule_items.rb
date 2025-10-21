class CreateOrganizationFeeScheduleItems < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_fee_schedule_items do |t|
      t.references :organization_fee_schedule, null: false, foreign_key: true
      t.references :procedure_code, null: false, foreign_key: true
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.string :pricing_rule, null: false
      t.boolean :active, default: true, null: false
      t.boolean :locked, default: false, null: false

      t.timestamps
    end

    add_index :organization_fee_schedule_items,
              [ :organization_fee_schedule_id, :procedure_code_id ],
              unique: true,
              name: 'index_fee_schedule_items_on_schedule_and_procedure'

    add_index :organization_fee_schedule_items, :active
    add_index :organization_fee_schedule_items, :locked
  end
end
