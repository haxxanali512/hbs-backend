class AddEncounterVisibilityStatuses < ActiveRecord::Migration[7.2]
  def change
    add_column :encounters, :tenant_status, :integer, default: 0, null: false
    add_column :encounters, :internal_status, :integer
    add_column :encounters, :shared_status, :integer

    add_index :encounters, :tenant_status
    add_index :encounters, :internal_status
    add_index :encounters, :shared_status

    reversible do |dir|
      dir.up do
        # Mark existing submitted/cascaded encounters as in_process for tenants.
        execute <<~SQL.squish
          UPDATE encounters
          SET tenant_status = 1
          WHERE status IN (5, 6) OR cascaded = TRUE
        SQL
      end
    end
  end
end
