class AddLockedToOrganizationFeeSchedules < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_fee_schedules, :locked, :boolean, default: false, null: false
  end
end
