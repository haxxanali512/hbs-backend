class AddPaymentStatusToPaymentApplications < ActiveRecord::Migration[7.2]
  def change
    add_column :payment_applications, :line_status, :integer, null: true
    add_column :payment_applications, :denial_reason, :text
    add_column :payment_applications, :note, :text

    add_index :payment_applications, :line_status
  end
end

