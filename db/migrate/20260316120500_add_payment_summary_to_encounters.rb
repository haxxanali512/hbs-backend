class AddPaymentSummaryToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_column :encounters, :payment_status, :integer, null: true
    add_column :encounters, :payment_date, :date
    add_column :encounters, :total_paid_amount, :decimal, precision: 10, scale: 2, default: 0, null: false

    add_index :encounters, :payment_status
    add_index :encounters, :payment_date
  end
end

