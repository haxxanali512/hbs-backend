class CreateSupportTickets < ActiveRecord::Migration[7.2]
  def change
    create_table :support_tickets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :created_by_user, null: false, foreign_key: { to_table: :users }
      t.references :assigned_to_user, foreign_key: { to_table: :users }

      t.integer :category, null: false
      t.string :subject, null: false, limit: 200
      t.text :description, null: false
      t.integer :priority, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.string :linked_resource_type
      t.string :linked_resource_id

      t.uuid :attachments, array: true, default: []
      t.jsonb :internal_notes, null: false, default: []

      t.datetime :first_response_due_at, null: false
      t.datetime :resolution_due_at, null: false
      t.datetime :closed_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :support_tickets, :category
    add_index :support_tickets, :priority
    add_index :support_tickets, :status
    add_index :support_tickets, :first_response_due_at
    add_index :support_tickets, :resolution_due_at
    add_index :support_tickets, :discarded_at
    add_index :support_tickets,
              %i[linked_resource_type linked_resource_id],
              name: "index_support_tickets_on_linked_resource"
  end
end
