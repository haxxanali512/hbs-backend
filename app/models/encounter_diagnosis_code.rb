class EncounterDiagnosisCode < ApplicationRecord
  belongs_to :diagnosis_code
  belongs_to :encounter
end
