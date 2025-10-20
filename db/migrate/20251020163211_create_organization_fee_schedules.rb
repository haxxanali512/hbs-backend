class CreateOrganizationFeeSchedules < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_fee_schedules do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :provider, null: false, foreign_key: true
      t.string :name
      t.integer :currency
      t.text :notes

      t.timestamps
    end
  end
end
