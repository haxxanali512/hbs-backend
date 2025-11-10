class AddCoverageIdToEncountersAndClaims < ActiveRecord::Migration[7.2]
  def change
    add_reference :encounters, :patient_insurance_coverage, foreign_key: true, null: true
    add_reference :claims, :patient_insurance_coverage, foreign_key: true, null: true
  end
end
