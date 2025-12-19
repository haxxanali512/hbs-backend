class CreateProcedureCodeRules < ActiveRecord::Migration[7.2]
  def change
    create_table :procedure_code_rules do |t|
      t.references :procedure_code, null: false, foreign_key: true, index: { unique: true }
      t.boolean :time_based, default: false
      t.string :pricing_type # "per unit" or "per procedure"
      t.jsonb :special_rules, default: []

      t.timestamps
    end
  end
end
