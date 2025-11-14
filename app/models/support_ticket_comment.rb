class SupportTicketComment < ApplicationRecord
  audited

  belongs_to :support_ticket
  belongs_to :author_user, class_name: "User"

  enum :visibility, {
    public: 0,
    internal: 1
  }, prefix: :visibility

  validates :body, presence: true, length: { maximum: 5_000 }
  validates :support_ticket, :author_user, :visibility, presence: true
  validate :phi_guard_for_public

  scope :chronological, -> { order(created_at: :asc) }
  scope :threaded_for_client, -> { visibility_public.chronological }

  after_create_commit :emit_events

  def internal?
    visibility == "internal"
  end

  private

  def phi_guard_for_public
    return if internal?

    PhiSafeTextValidator.ensure_safe!(self, :body, body)
  end

  def emit_events
    SupportTicketEventPublisher.comment_added(support_ticket, self)
    SupportTicketMailer.comment_added(support_ticket, self).deliver_later
  end
end
