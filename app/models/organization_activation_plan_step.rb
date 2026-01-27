class OrganizationActivationPlanStep < ApplicationRecord
  audited

  belongs_to :org_accepted_plan
  belongs_to :completed_by, class_name: "User", optional: true

  enum :step_type, {
    waystar_enrollment: 0,
    payer_enrollment: 1,
    payer_accepting_claims: 2,
    waystar_receiving_remits: 3
  }

  validates :org_accepted_plan_id, uniqueness: { scope: :step_type, message: "Step type already exists for this plan" }
  validates :step_type, presence: true

  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }

  def mark_completed!(user)
    update!(
      completed: true,
      completed_at: Time.current,
      completed_by: user
    )
  end

  def mark_pending!
    update!(
      completed: false,
      completed_at: nil,
      completed_by: nil
    )
  end
end
