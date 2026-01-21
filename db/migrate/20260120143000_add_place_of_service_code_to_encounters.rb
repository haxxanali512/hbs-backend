class AddPlaceOfServiceCodeToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_column :encounters, :place_of_service_code, :integer, null: false, default: 11
    add_index :encounters, :place_of_service_code
  end
end
