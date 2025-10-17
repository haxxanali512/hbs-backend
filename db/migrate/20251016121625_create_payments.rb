class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true, type: :uuid
      t.references :organization, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :payment_method, null: false, default: 0
      t.string :payment_provider_id
      t.jsonb :payment_provider_response
      t.integer :payment_status, null: false, default: 0
      t.datetime :paid_at
      t.references :processed_by_user, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end

    add_index :payments, :payment_provider_id
    add_index :payments, :payment_status
    add_index :payments, :paid_at
    add_index :payments, [ :invoice_id, :payment_status ]
    add_index :payments, [ :organization_id, :paid_at ]
  end
end
