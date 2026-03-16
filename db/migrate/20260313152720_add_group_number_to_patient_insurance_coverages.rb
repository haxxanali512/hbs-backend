class AddGroupNumberToPatientInsuranceCoverages < ActiveRecord::Migration[7.2]
  def change
    add_column :patient_insurance_coverages, :group_number, :string
  end
end
