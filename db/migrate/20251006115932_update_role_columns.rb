class UpdateRoleColumns < ActiveRecord::Migration[7.2]
  def change
    remove_column :roles, :user_id
    add_reference :users, :role, foreign_key: true
  end
end
