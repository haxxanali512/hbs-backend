class CreatePaymentAdjustments < ActiveRecord::Migration[7.2]
  def change
    create_table :payment_adjustments do |t|
      t.references :payment, null: false, foreign_key: true
      t.integer :adjustment_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.date :adjustment_date, null: false
      t.text :reason
      t.text :notes

      t.timestamps
    end

    add_index :payment_adjustments, :adjustment_date
    add_index :payment_adjustments, :adjustment_type
  end
end
