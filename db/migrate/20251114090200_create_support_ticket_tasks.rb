class CreateSupportTicketTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :support_ticket_tasks do |t|
      t.references :support_ticket, null: false, foreign_key: true
      t.integer :task_type, null: false
      t.integer :status, null: false, default: 0
      t.datetime :opened_at, null: false
      t.datetime :completed_at
      t.text :notes

      t.timestamps
    end

    add_index :support_ticket_tasks, %i[support_ticket_id task_type], name: "index_support_ticket_tasks_on_ticket_and_type"
    add_index :support_ticket_tasks, :status
  end
end
