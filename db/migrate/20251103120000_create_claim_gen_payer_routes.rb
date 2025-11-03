class CreateClaimGenPayerRoutes < ActiveRecord::Migration[7.2]
  def change
    create_table :claim_gen_payer_routes do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: true
      t.string :claimgen_account_key, null: false
      t.string :external_payer_code
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :claim_gen_payer_routes, [ :organization_id, :payer_id, :claimgen_account_key ], unique: true, name: "idx_claimgen_routes_unique"
  end
end
