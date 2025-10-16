class AddGoCardlessFieldsToOrganizationBillings < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_billings, :gocardless_customer_id, :string
    add_column :organization_billings, :gocardless_mandate_id, :string
  end
end
