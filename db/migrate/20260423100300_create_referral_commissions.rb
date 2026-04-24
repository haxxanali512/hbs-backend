class CreateReferralCommissions < ActiveRecord::Migration[7.2]
  def change
    drop_table :referral_commissions, if_exists: true

    create_table :referral_commissions do |t|
      t.references :referral_relationship, null: false, foreign_key: true
      t.date :month, null: false
      t.decimal :eligible_revenue, precision: 12, scale: 2, default: 0, null: false
      t.decimal :commission_percent, precision: 5, scale: 2, default: 12.0, null: false
      t.decimal :commission_amount, precision: 12, scale: 2, default: 0, null: false
      t.integer :payout_status, null: false, default: 0
      t.date :payout_date
      t.text :notes

      t.timestamps
    end

    add_index :referral_commissions, [ :referral_relationship_id, :month ], unique: true, name: "idx_ref_commissions_unique_month"
  end
end
