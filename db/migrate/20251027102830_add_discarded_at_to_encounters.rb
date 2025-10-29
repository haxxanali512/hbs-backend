class AddDiscardedAtToEncounters < ActiveRecord::Migration[7.2]
  def change
    add_column :encounters, :discarded_at, :timestamp
  end
end
