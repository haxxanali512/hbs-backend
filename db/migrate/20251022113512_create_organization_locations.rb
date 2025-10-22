class CreateOrganizationLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_locations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name
      t.integer :status
      t.string :place_of_service_code
      t.boolean :is_virtual
      t.text :address_line_1
      t.text :address_line_2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country
      t.string :phone_number
      t.string :billing_npi
      t.string :taxonomy_code
      t.string :hours
      t.text :notes_internal
      t.timestamp :discarded_at
      t.boolean :locked

      t.timestamps
    end
  end
end
