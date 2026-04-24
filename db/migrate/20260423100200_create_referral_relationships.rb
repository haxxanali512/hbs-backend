class CreateReferralRelationships < ActiveRecord::Migration[7.2]
  def change
    drop_table :referral_relationships, if_exists: true

    create_table :referral_relationships do |t|
      t.references :referral_partner, null: false, foreign_key: true
      t.references :referred_org, null: false, foreign_key: { to_table: :organizations }
      t.string :referral_source
      t.string :referred_practice_name
      t.date :contract_signed_date
      t.date :commission_start_date
      t.date :commission_end_date
      t.string :tier_selected
      t.integer :status, null: false, default: 0
      t.text :ineligibility_reason
      t.decimal :total_revenue_to_date, precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_commission_to_date, precision: 12, scale: 2, default: 0, null: false
      t.integer :eligibility_status, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :referral_relationships, [ :referral_partner_id, :referred_org_id ], unique: true, name: "idx_ref_relationship_partner_org"
  end
end
