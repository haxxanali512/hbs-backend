class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices, id: :uuid do |t|
      t.string :invoice_number, null: false
      t.references :organization, null: false, foreign_key: true

      # Type and status enums (stored as integers)
      t.integer :invoice_type, null: false, default: 0
      t.integer :status, null: false, default: 0

      # Dates
      t.date :issue_date
      t.date :due_date
      t.date :service_period_start
      t.date :service_period_end
      t.string :service_month # YYYY-MM format

      # Currency and monetary fields
      t.string :currency, default: "USD", null: false
      t.decimal :subtotal, precision: 10, scale: 2, default: 0.0
      t.decimal :total, precision: 10, scale: 2, default: 0.0
      t.decimal :amount_paid, precision: 10, scale: 2, default: 0.0
      t.decimal :amount_credited, precision: 10, scale: 2, default: 0.0
      t.decimal :amount_due, precision: 10, scale: 2, default: 0.0

      # Revenue share specific fields
      t.decimal :percent_of_revenue_snapshot, precision: 5, scale: 2
      t.decimal :collected_revenue_amount, precision: 10, scale: 2
      t.integer :deductible_applied_claims_count
      t.decimal :deductible_fee_snapshot, precision: 10, scale: 2, default: 10.0
      t.decimal :adjustments_total, precision: 10, scale: 2, default: 0.0

      # Payment tracking
      t.datetime :latest_payment_at

      # Exception handling
      t.integer :exception_type
      t.text :exception_reason
      t.date :exception_through
      t.references :exception_set_by_user, foreign_key: { to_table: :users }
      t.datetime :exception_set_at

      # Notes
      t.text :notes_internal
      t.text :notes_client

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :status
    add_index :invoices, :invoice_type
    add_index :invoices, :due_date
    add_index :invoices, :service_month
    add_index :invoices, [ :organization_id, :service_month ]
  end
end
