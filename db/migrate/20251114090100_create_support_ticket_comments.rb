class CreateSupportTicketComments < ActiveRecord::Migration[7.2]
  def change
    create_table :support_ticket_comments do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.references :author_user, null: false, foreign_key: { to_table: :users }

      t.integer :visibility, null: false, default: 0
      t.text :body, null: false
      t.boolean :system_generated, null: false, default: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :support_ticket_comments, :visibility
    add_index :support_ticket_comments, :created_at
  end
end
