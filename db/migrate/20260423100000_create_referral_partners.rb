class CreateReferralPartners < ActiveRecord::Migration[7.2]
  def change
    drop_table :referral_commissions, if_exists: true
    drop_table :referral_relationships, if_exists: true
    drop_table :referral_partners, if_exists: true

    create_table :referral_partners do |t|
      t.references :user, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.integer :partner_type, null: false, default: 0
      t.string :referral_code
      t.string :referral_url
      t.integer :status, null: false, default: 0
      t.datetime :agreement_signed_at
      t.datetime :approved_at
      t.string :tax_form_status
      t.text :notes
      t.references :linked_client, foreign_key: { to_table: :organizations }

      t.timestamps
    end

    add_index :referral_partners, "LOWER(email)", unique: true, name: "idx_referral_partners_lower_email"
    add_index :referral_partners, :referral_code, unique: true
  end
end
