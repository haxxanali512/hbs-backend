class CreatePatients < ActiveRecord::Migration[7.2]
  def change
    create_table :patients do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.datetime :dob
      t.string :sex_at_birth
      t.text :address_line_1
      t.text :address_line_2
      t.string :city
      t.string :state
      t.string :postal
      t.string :country
      t.string :phone_number
      t.string :email
      t.string :mrn
      t.string :external_id
      t.integer :status
      t.timestamp :deceased_at
      t.text :notes_nonphi

      t.timestamps
    end
  end
end
