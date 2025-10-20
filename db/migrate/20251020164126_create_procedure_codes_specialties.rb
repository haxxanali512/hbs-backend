class CreateProcedureCodesSpecialties < ActiveRecord::Migration[7.2]
  def change
    create_table :procedure_codes_specialties do |t|
      t.references :specialty, null: false, foreign_key: true
      t.references :procedure_code, null: false, foreign_key: true

      t.timestamps
    end
  end
end
