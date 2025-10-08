class CreateOrganizations < ActiveRecord::Migration[7.2]
  def change
    create_table :organizations do |t|
      t.string :name
      t.string :subdomain
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :tier
      t.integer :activation_state
      t.timestamp :activation_state_changed_at
      t.timestamp :closed_at

      t.timestamps
    end
  end
end
