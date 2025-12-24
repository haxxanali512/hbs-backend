class ChangeTierToEnumInOrganizations < ActiveRecord::Migration[7.2]
  def up
    # Add new integer column
    add_column :organizations, :tier_new, :integer

    # Map existing string values to enum values
    # Only map valid percentage values (6%, 7%, 8%, 9%)
    # For invalid or NULL values, default to 6%
    execute <<-SQL
      UPDATE organizations
      SET tier_new = CASE
        WHEN tier = '6%' OR tier LIKE '6%' THEN 0
        WHEN tier = '7%' OR tier LIKE '7%' THEN 1
        WHEN tier = '8%' OR tier LIKE '8%' THEN 2
        WHEN tier = '9%' OR tier LIKE '9%' THEN 3
        ELSE 0
      END
    SQL

    # Remove old column
    remove_column :organizations, :tier

    # Rename new column
    rename_column :organizations, :tier_new, :tier

    # Add not null constraint with default
    change_column_default :organizations, :tier, 0
    change_column_null :organizations, :tier, false
  end

  def down
    # Convert back to string
    add_column :organizations, :tier_string, :string

    execute <<-SQL
      UPDATE organizations
      SET tier_string = CASE
        WHEN tier = 0 THEN '6%'
        WHEN tier = 1 THEN '7%'
        WHEN tier = 2 THEN '8%'
        WHEN tier = 3 THEN '9%'
        ELSE NULL
      END
    SQL

    remove_column :organizations, :tier
    rename_column :organizations, :tier_string, :tier
  end
end
