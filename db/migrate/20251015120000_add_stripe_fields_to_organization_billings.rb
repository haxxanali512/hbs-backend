class AddStripeFieldsToOrganizationBillings < ActiveRecord::Migration[7.2]
  def change
    change_table :organization_billings, bulk: true do |t|
      t.string  :stripe_customer_id
      t.string  :stripe_subscription_id
      t.string  :stripe_session_id
      t.string  :stripe_payment_method_id
      t.string  :card_brand
      t.integer :card_exp_month
      t.integer :card_exp_year
    end

    add_index :organization_billings, :stripe_customer_id
    add_index :organization_billings, :stripe_subscription_id
  end
end
