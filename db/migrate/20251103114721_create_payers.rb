class CreatePayers < ActiveRecord::Migration[7.2]
  def change
    create_table :payers do |t|
      t.string :name
      t.integer :payer_type
      t.integer :id_namespace
      t.integer :national_payer_id
      t.string :contact_url
      t.string :support_phone
      t.text :notes_internal
      t.string :state_scope, array: true, default: []
      t.integer :status

      t.timestamps
    end
  end
end
