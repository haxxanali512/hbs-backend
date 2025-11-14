class SupportTicketTask < ApplicationRecord
  audited

  belongs_to :support_ticket

  enum :task_type, {
    first_response: 0,
    resolution: 1
  }

  enum :status, {
    open: 0,
    completed: 1
  }

  validates :support_ticket, :task_type, :status, :opened_at, presence: true

  scope :open_tasks, -> { where(status: :open) }

  def complete!(completed_at: Time.current)
    update!(status: :completed, completed_at: completed_at)
  end
end
