class CreateDenialItems < ActiveRecord::Migration[7.2]
  def change
    create_table :denial_items do |t|
      t.references :denial, null: false, foreign_key: true
      t.references :claim_line, null: false, foreign_key: true
      t.decimal :amount_denied, precision: 10, scale: 2, null: false, default: 0
      t.string :carc_codes, array: true, default: []
      t.string :rarc_codes, array: true, default: []
      t.timestamps
    end
  end
end
