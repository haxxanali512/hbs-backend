class UpdateProviderStatusEnum < ActiveRecord::Migration[7.2]
  def up
    # Map existing statuses to new values
    # draft -> drafted
    # pending -> pending (no change)
    # approved -> approved (no change)
    # rejected -> deactivated
    # suspended -> deactivated

    execute <<-SQL
      UPDATE providers
      SET status = CASE
        WHEN status = 'draft' THEN 'drafted'
        WHEN status = 'rejected' THEN 'deactivated'
        WHEN status = 'suspended' THEN 'deactivated'
        ELSE status
      END
    SQL
  end

  def down
    # Reverse mapping
    execute <<-SQL
      UPDATE providers
      SET status = CASE
        WHEN status = 'drafted' THEN 'draft'
        WHEN status = 'deactivated' THEN 'suspended'
        ELSE status
      END
    SQL
  end
end
