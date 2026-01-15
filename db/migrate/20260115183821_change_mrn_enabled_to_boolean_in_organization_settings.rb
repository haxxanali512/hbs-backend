class ChangeMrnEnabledToBooleanInOrganizationSettings < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE organization_settings
      SET mrn_enabled = 'true'
      WHERE mrn_enabled IS NULL OR mrn_enabled = '';
    SQL

    change_column :organization_settings,
                  :mrn_enabled,
                  :boolean,
                  using: "mrn_enabled::boolean",
                  default: true,
                  null: false
  end

  def down
    change_column :organization_settings,
                  :mrn_enabled,
                  :string,
                  using: "mrn_enabled::text",
                  default: nil,
                  null: true

    execute <<~SQL
      UPDATE organization_settings
      SET mrn_enabled = CASE WHEN mrn_enabled = 't' THEN 'true' ELSE 'false' END
    SQL
  end
end
