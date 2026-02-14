class AddTimeZoneToOrganizationSettings < ActiveRecord::Migration[7.2]
  DEFAULT_TZ = "America/New_York"

  def up
    add_column :organization_settings, :time_zone, :string, default: DEFAULT_TZ
    execute <<-SQL.squish
      UPDATE organization_settings SET time_zone = '#{DEFAULT_TZ}' WHERE time_zone IS NULL
    SQL
  end

  def down
    remove_column :organization_settings, :time_zone
  end
end
