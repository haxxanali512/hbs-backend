class AddPlanIdToClaimSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_reference :claim_submissions, :insurance_plan, foreign_key: true
  end
end
