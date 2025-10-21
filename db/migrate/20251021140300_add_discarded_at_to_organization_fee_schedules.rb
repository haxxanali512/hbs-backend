class AddDiscardedAtToOrganizationFeeSchedules < ActiveRecord::Migration[7.2]
  def change
    add_column :organization_fee_schedules, :discarded_at, :timestamp
    add_index :organization_fee_schedules, :discarded_at
  end
end
