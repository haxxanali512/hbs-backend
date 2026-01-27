class ActivationChecklist < ApplicationRecord
  audited

  belongs_to :organization

  validates :organization_id, uniqueness: true

  def all_manual_steps_complete?
    waystar_child_account_completed? &&
      ezclaim_record_completed? &&
      initial_encounter_billed_completed? &&
      name_match_completed?
  end
end
