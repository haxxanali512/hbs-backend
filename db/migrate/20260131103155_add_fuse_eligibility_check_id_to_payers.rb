class AddFuseEligibilityCheckIdToPayers < ActiveRecord::Migration[7.2]
  def change
    add_column :payers, :fuse_eligibility_check_id, :string
    add_index :payers, :fuse_eligibility_check_id, where: "fuse_eligibility_check_id IS NOT NULL AND fuse_eligibility_check_id != ''"
  end
end
