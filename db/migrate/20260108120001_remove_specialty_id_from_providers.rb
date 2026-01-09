class RemoveSpecialtyIdFromProviders < ActiveRecord::Migration[7.2]
  def up
    # Migrate existing data to join table
    execute <<-SQL
      INSERT INTO provider_specialties (provider_id, specialty_id, created_at, updated_at)
      SELECT id, specialty_id, created_at, updated_at
      FROM providers
      WHERE specialty_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    # Remove the old column
    remove_column :providers, :specialty_id
  end

  def down
    # Add back the column
    add_column :providers, :specialty_id, :bigint

    # Migrate data back (use first specialty if multiple)
    execute <<-SQL
      UPDATE providers
      SET specialty_id = (
        SELECT specialty_id
        FROM provider_specialties
        WHERE provider_specialties.provider_id = providers.id
        ORDER BY created_at ASC
        LIMIT 1
      )
    SQL

    add_foreign_key :providers, :specialties, column: :specialty_id
  end
end
