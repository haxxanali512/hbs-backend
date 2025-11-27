class NotificationsController < ApplicationController
  layout "application"

  def index
    @notifications = current_user.notifications.recent.includes(:organization)
    @unread_count = current_user.notifications.unread.count
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.json { render json: { success: true, unread_count: current_user.notifications.unread.count } }
      format.turbo_stream
    end
  end

  def mark_all_as_read
    notification_ids = current_user.notifications.unread.pluck(:id)
    current_user.notifications.unread.update_all(read: true, read_at: Time.current)

    # Reload notifications to get updated state
    notifications = Notification.where(id: notification_ids)

    # Broadcast updates for all notifications
    notifications.each do |notification|
      notification.broadcast_replace_to(
        "user_#{current_user.id}_notifications",
        target: "notification_#{notification.id}",
        partial: "notifications/notification_item",
        locals: { notification: notification.reload }
      )
    end

    # Update badge via Turbo Stream
    respond_to do |format|
      format.json { render json: { success: true, unread_count: 0 } }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { unread_count: 0 })
        ]
      end
    end
  end

  def unread_count
    render json: { count: current_user.notifications.unread.count }
  end
end
