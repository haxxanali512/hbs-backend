class CreateDiagnosisCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :diagnosis_codes do |t|
      t.string :code
      t.text :description
      t.integer :status
      t.datetime :effective_from
      t.datetime :effective_to

      t.timestamps
    end
  end
end
