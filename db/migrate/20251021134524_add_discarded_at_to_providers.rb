class AddDiscardedAtToProviders < ActiveRecord::Migration[7.2]
  def change
    add_column :providers, :discarded_at, :datetime
    add_index :providers, :discarded_at
  end
end
