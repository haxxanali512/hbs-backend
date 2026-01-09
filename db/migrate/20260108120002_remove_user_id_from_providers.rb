class RemoveUserIdFromProviders < ActiveRecord::Migration[7.2]
  def change
    remove_column :providers, :user_id, :uuid
  end
end
