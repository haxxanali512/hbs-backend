class PrescriptionDiagnosisCode < ApplicationRecord
  audited

  belongs_to :prescription
  belongs_to :diagnosis_code

  validates :prescription_id, uniqueness: { scope: :diagnosis_code_id }
end
