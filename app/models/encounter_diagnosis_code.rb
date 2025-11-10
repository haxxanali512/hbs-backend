class EncounterDiagnosisCode < ApplicationRecord
  audited
  belongs_to :diagnosis_code
  belongs_to :encounter
end
