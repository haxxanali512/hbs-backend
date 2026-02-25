class AddBilledFieldsToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_reference :encounters, :billed_by, foreign_key: { to_table: :users }
    add_column :encounters, :billed_at, :datetime
  end
end

