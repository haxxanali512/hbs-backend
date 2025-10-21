class AddFieldsToProcedureCodes < ActiveRecord::Migration[7.2]
  def change
    add_column :procedure_codes, :code_type, :integer, default: 0, null: false
    add_column :procedure_codes, :status, :integer, default: 0, null: false
    add_column :procedure_codes, :discarded_at, :datetime
    add_index :procedure_codes, :discarded_at
    add_index :procedure_codes, :code_type
    add_index :procedure_codes, :status
    add_index :procedure_codes, [ :code, :code_type ], unique: true
  end
end
