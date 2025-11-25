class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.references :organization, null: true, foreign_key: true, type: :bigint
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :message, null: false
      t.string :action_url
      t.boolean :read, default: false, null: false
      t.timestamp :read_at
      t.jsonb :metadata

      t.timestamps
    end

    add_index :notifications, [ :user_id, :read ]
    add_index :notifications, [ :user_id, :created_at ]
    add_index :notifications, :notification_type
  end
end
