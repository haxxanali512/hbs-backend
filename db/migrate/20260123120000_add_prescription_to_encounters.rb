class AddPrescriptionToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_reference :encounters, :prescription, foreign_key: true
  end
end
