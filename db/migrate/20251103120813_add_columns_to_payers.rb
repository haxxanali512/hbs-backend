class AddColumnsToPayers < ActiveRecord::Migration[7.2]
  def change
    add_column :payers, :hbs_payer_key, :string
    add_column :payers, :search_tokens, :text
  end
end
