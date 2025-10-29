class ChangeDobToDateInPatients < ActiveRecord::Migration[7.2]
  def up
    change_column :patients, :dob, :date
  end

  def down
    change_column :patients, :dob, :datetime
  end
end
