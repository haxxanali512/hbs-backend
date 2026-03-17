class AllowNullInvoiceIdOnPayments < ActiveRecord::Migration[7.2]
  def change
    change_column_null :payments, :invoice_id, true
  end
end

