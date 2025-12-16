class OrganizationFeeScheduleSpecialty < ApplicationRecord
  audited

  belongs_to :organization_fee_schedule
  belongs_to :specialty

  validates :organization_fee_schedule_id, uniqueness: { scope: :specialty_id }
end
