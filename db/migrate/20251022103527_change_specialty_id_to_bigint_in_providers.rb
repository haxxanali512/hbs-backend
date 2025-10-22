class ChangeSpecialtyIdToBigintInProviders < ActiveRecord::Migration[7.2]
  def up
    # Remove the old column
    remove_column :providers, :specialty_id

    # Add the new column with correct type
    add_column :providers, :specialty_id, :bigint

    # Add the foreign key constraint
    add_foreign_key :providers, :specialties, column: :specialty_id
  end

  def down
    # Remove the foreign key constraint
    remove_foreign_key :providers, :specialties

    # Remove the bigint column
    remove_column :providers, :specialty_id

    # Add back the uuid column
    add_column :providers, :specialty_id, :uuid
  end
end
