class AddSubCategoryToSupportTickets < ActiveRecord::Migration[7.2]
  def change
    add_column :support_tickets, :sub_category, :integer
    add_index :support_tickets, :sub_category
  end
end
