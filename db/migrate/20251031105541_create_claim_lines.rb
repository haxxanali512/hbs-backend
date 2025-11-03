class CreateClaimLines < ActiveRecord::Migration[7.2]
  def change
    create_table :claim_lines do |t|
      t.references :claim, null: false, foreign_key: true
      t.references :procedure_code, null: false, foreign_key: true

      t.integer :units, null: false, default: 1
      t.decimal :amount_billed, precision: 10, scale: 2, null: false, default: 0

      t.string :modifiers, array: true, default: []
      t.integer :dx_pointers_numeric, array: true, default: []

      t.string :place_of_service_code, null: false
      t.string :status, null: false, default: "generated"

      t.string :adjudication_group_codes, array: true, default: []
      t.string :adjudication_carc_codes, array: true, default: []
      t.string :adjudication_rarc_codes, array: true, default: []

      t.decimal :adjudicated_amount, precision: 10, scale: 2
      t.decimal :balance_remaining, precision: 10, scale: 2, default: 0

      t.timestamps
    end
  end
end
