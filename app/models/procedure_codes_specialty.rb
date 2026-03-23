class ProcedureCodesSpecialty < ApplicationRecord
  audited

  belongs_to :specialty
  belongs_to :procedure_code

  after_commit :sync_specialty_fee_schedule_items, on: [ :create ]

  private

  def sync_specialty_fee_schedule_items
    specialty&.sync_fee_schedule_items_for_mapped_cpts!
  rescue => e
    Rails.logger.warn("ProcedureCodesSpecialty sync fee schedule failed: #{e.message}")
  end
end
