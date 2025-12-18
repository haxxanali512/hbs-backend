class EncounterProcedureItem < ApplicationRecord
  audited
  belongs_to :encounter
  belongs_to :procedure_code

  validates :encounter_id, uniqueness: { scope: :procedure_code_id, message: "PROCEDURE_CODE_ALREADY_ADDED" }

  scope :primary, -> { where(is_primary: true) }
  scope :secondary, -> { where(is_primary: false) }
end
