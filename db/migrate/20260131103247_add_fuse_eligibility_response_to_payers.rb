class AddFuseEligibilityResponseToPayers < ActiveRecord::Migration[7.2]
  def change
    add_column :payers, :fuse_eligibility_status, :string
    add_column :payers, :fuse_eligibility_response, :jsonb
    add_column :payers, :fuse_eligibility_updated_at, :datetime
  end
end
