class CreateProcedureCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :procedure_codes do |t|
      t.string :code
      t.text :description

      t.timestamps
    end
  end
end
