class CreateOrganizationMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :organization_role, null: true, foreign_key: { to_table: :roles }
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :organization_memberships, [ :user_id, :organization_id ], unique: true
  end
end
