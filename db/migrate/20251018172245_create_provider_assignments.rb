class CreateProviderAssignments < ActiveRecord::Migration[7.2]
  def change
    create_table :provider_assignments do |t|
      t.references :provider, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.integer :role
      t.boolean :active

      t.timestamps
    end
  end
end
