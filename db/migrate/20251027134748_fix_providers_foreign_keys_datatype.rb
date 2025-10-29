class FixProvidersForeignKeysDatatype < ActiveRecord::Migration[7.2]
  def change
    # Change user_id from uuid to bigint to match users.id (bigint)
    change_column :providers, :user_id, :bigint, using: 'user_id::text::bigint'

    # Change specialty_id from uuid to bigint to match specialties.id (bigint)
    change_column :providers, :specialty_id, :bigint

    # Add foreign key constraint for user_id if it doesn't exist
    add_foreign_key :providers, :users, column: :user_id unless foreign_key_exists?(:providers, :users)
  end
end
