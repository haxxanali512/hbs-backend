class CreatePaymentApplications < ActiveRecord::Migration[7.2]
  def change
    create_table :payment_applications do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :claim, null: false, foreign_key: true
      t.references :claim_line, foreign_key: true
      t.decimal :amount_applied, precision: 10, scale: 2, null: false, default: 0
      t.bigint :patient_id, null: false
      t.bigint :encounter_id, null: false
      t.timestamps
    end

    add_index :payment_applications, [ :claim_id, :claim_line_id ]
  end
end
