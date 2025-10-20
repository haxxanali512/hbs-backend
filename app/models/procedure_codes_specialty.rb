class ProcedureCodesSpecialty < ApplicationRecord
  audited

  belongs_to :specialty
  belongs_to :procedure_code
end
