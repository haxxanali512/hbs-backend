class AddScopeAndOrganizationToRoles < ActiveRecord::Migration[7.2]
  def change
    add_column :roles, :scope, :integer, default: 0 # 0=global, 1=tenant
    add_reference :roles, :organization, null: true, foreign_key: true
    add_index :roles, [ :scope, :organization_id ]
  end
end
