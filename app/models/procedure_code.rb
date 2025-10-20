class ProcedureCode < ApplicationRecord
  audited

  has_many :procedure_codes_specialties, dependent: :destroy
  has_many :specialties, through: :procedure_codes_specialties

  validates :code, presence: true, uniqueness: true
  validates :description, presence: true
end
