class CreateRoles < ActiveRecord::Migration[7.2]
  def change
    create_table :roles do |t|
      t.string :role_name
      t.jsonb :access
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
