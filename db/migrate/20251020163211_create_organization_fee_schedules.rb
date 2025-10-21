class CreateOrganizationFeeSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_fee_schedules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :provider, null: true, foreign_key: true
      t.string :name, null: false
      t.integer :currency, null: false, default: 0
      t.text :notes
      t.boolean :locked, default: false, null: false

      t.timestamps
    end

    add_index :organization_fee_schedules, [ :organization_id, :provider_id ],
              name: 'index_org_fee_schedules_on_org_and_provider'
  end
end
