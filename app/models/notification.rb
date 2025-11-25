class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :organization, optional: true

  # Notification types
  NOTIFICATION_TYPES = {
    organization_created: "organization_created",
    organization_updated: "organization_updated",
    organization_activated: "organization_activated",
    organization_suspended: "organization_suspended",
    organization_deleted: "organization_deleted",
    billing_approved: "billing_approved",
    billing_rejected: "billing_rejected",
    provider_approved: "provider_approved",
    provider_rejected: "provider_rejected",
    provider_suspended: "provider_suspended",
    user_invited: "user_invited",
    user_role_changed: "user_role_changed"
  }.freeze

  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_organization, ->(org_id) { where(organization_id: org_id) }
  scope :by_type, ->(type) { where(notification_type: type) }

  validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES.values }
  validates :title, presence: true
  validates :message, presence: true

  after_create_commit :broadcast_to_user
  after_update_commit :broadcast_update, if: :saved_change_to_read?

  def mark_as_read!
    update!(read: true, read_at: Time.current) unless read?
  end

  private

  def broadcast_to_user
    # Remove empty state if it exists
    broadcast_remove_to("user_#{user_id}_notifications", target: "notifications_empty_state")

    # Prepend new notification
    broadcast_prepend_to(
      "user_#{user_id}_notifications",
      target: "notifications_list",
      partial: "notifications/notification_item",
      locals: { notification: self }
    )

    # Update badge
    broadcast_replace_to(
      "user_#{user_id}_notifications",
      target: "notifications_badge",
      partial: "notifications/badge",
      locals: { unread_count: user.notifications.unread.count }
    )
  end

  def broadcast_update
    broadcast_replace_to(
      "user_#{user_id}_notifications",
      target: "notification_#{id}",
      partial: "notifications/notification_item",
      locals: { notification: self }
    )
    broadcast_replace_to(
      "user_#{user_id}_notifications",
      target: "notifications_badge",
      partial: "notifications/badge",
      locals: { unread_count: user.notifications.unread.count }
    )
  end

  def mark_as_unread!
    update!(read: false, read_at: nil) if read?
  end

  def read?
    read
  end

  def unread?
    !read
  end
end
