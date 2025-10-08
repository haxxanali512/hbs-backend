class CreateOrganizationBillings < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_billings do |t|
      t.references :organization, null: false, foreign_key: true
      t.integer :billing_status
      t.timestamp :last_payment_date
      t.timestamp :next_payment_due
      t.string :method_last4
      t.integer :provider

      t.timestamps
    end
  end
end
