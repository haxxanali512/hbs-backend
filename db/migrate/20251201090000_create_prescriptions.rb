class CreatePrescriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :prescriptions do |t|
      t.bigint :patient_id, null: false
      t.date   :expires_on, null: false
      t.boolean :expired, default: false, null: false
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :prescriptions, :patient_id, unique: true
    add_index :prescriptions, :expires_on
    add_index :prescriptions, :discarded_at
    add_index :prescriptions, :expired
  end
end


