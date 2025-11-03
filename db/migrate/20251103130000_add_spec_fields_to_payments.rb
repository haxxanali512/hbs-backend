class AddSpecFieldsToPayments < ActiveRecord::Migration[7.2]
  def change
    add_reference :payments, :payer, foreign_key: true
    add_column :payments, :payment_date, :date
    add_column :payments, :amount_total, :decimal, precision: 10, scale: 2
    add_column :payments, :remit_reference, :string
    add_column :payments, :source_hash, :string

    add_index :payments, [ :organization_id, :payer_id, :remit_reference ], unique: true, name: "idx_payments_org_payer_remit"
    add_index :payments, :source_hash, unique: true
  end
end
