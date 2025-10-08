class CreateOrganizationContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_contacts do |t|
      t.references :organization, null: false, foreign_key: true
      t.text :address_line1
      t.text :address_line2
      t.string :city
      t.string :state
      t.string :zip
      t.string :country
      t.string :phone
      t.string :email
      t.string :time_zone
      t.integer :contact_type

      t.timestamps
    end
  end
end
