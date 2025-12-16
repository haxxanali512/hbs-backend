class ChangePricingRuleToIntegerInOrgFeeScheduleItems < ActiveRecord::Migration[7.2]
  def up
    # Map existing string values to integer enum:
    # 0 => price_per_unit (default), 1 => flat
    add_column :organization_fee_schedule_items, :pricing_rule_int, :integer, default: 0, null: false

    execute <<-SQL.squish
      UPDATE organization_fee_schedule_items
      SET pricing_rule_int = CASE pricing_rule
                               WHEN 'flat' THEN 1
                               ELSE 0
                             END
    SQL

    remove_column :organization_fee_schedule_items, :pricing_rule
    rename_column :organization_fee_schedule_items, :pricing_rule_int, :pricing_rule
  end

  def down
    add_column :organization_fee_schedule_items, :pricing_rule_str, :string, null: false, default: 'price_per_unit'

    execute <<-SQL.squish
      UPDATE organization_fee_schedule_items
      SET pricing_rule_str = CASE pricing_rule
                               WHEN 1 THEN 'flat'
                               ELSE 'price_per_unit'
                             END
    SQL

    remove_column :organization_fee_schedule_items, :pricing_rule
    rename_column :organization_fee_schedule_items, :pricing_rule_str, :pricing_rule
  end
end
