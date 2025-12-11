class AllowNullUnitPriceInOrganizationFeeScheduleItems < ActiveRecord::Migration[7.2]
  def change
    change_column_null :organization_fee_schedule_items, :unit_price, true
  end
end
