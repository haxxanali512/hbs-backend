class CreateReferralPartners < ActiveRecord::Migration[7.2]
  def change
    create_table :referral_partners do |t|
      t.references :user, null: true, foreign_key: true
      t.references :linked_client_organization, null: true, foreign_key: { to_table: :organizations }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.integer :partner_type, null: false, default: 6
      t.integer :status, null: false, default: 0
      t.string :referral_code
      t.string :referral_url
      t.datetime :agreement_signed_at
      t.datetime :approved_at
      t.string :tax_form_status
      t.text :notes

      t.timestamps
    end

    add_index :referral_partners, "LOWER(email)", unique: true, name: "index_referral_partners_on_lower_email"
    add_index :referral_partners, :referral_code, unique: true
  end
end
