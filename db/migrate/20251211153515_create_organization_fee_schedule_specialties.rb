class CreateOrganizationFeeScheduleSpecialties < ActiveRecord::Migration[7.2]
  def change
    create_table :organization_fee_schedule_specialties do |t|
      t.references :organization_fee_schedule, null: false, foreign_key: true, type: :bigint
      t.references :specialty, null: false, foreign_key: true, type: :bigint
      t.timestamps
    end

    add_index :organization_fee_schedule_specialties,
              [ :organization_fee_schedule_id, :specialty_id ],
              unique: true,
              name: 'index_org_fee_schedule_specialties_unique'
  end
end
