class Specialty < ApplicationRecord
  audited

  has_many :procedure_codes_specialties, dependent: :destroy
  has_many :procedure_codes, through: :procedure_codes_specialties
end
