class RemoveColumnFromRoles < ActiveRecord::Migration[7.2]
  def change
    remove_reference :roles, :organization, foreign_key: true
  end
end
