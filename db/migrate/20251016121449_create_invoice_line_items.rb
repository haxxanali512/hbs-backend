class CreateInvoiceLineItems < ActiveRecord::Migration[7.2]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true, type: :uuid
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2
      t.decimal :unit_price, precision: 10, scale: 2
      t.decimal :percent_applied, precision: 5, scale: 2
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.jsonb :calc_ref
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :invoice_line_items, :position
  end
end
