class AddDiscardedAtToSpecialties < ActiveRecord::Migration[7.2]
  def change
    add_column :specialties, :discarded_at, :datetime
    add_index :specialties, :discarded_at
  end
end
