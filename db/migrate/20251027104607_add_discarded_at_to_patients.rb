class AddDiscardedAtToPatients < ActiveRecord::Migration[7.2]
  def change
    add_column :patients, :discarded_at, :timestamp
  end
end
