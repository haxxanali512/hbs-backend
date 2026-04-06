class NotificationsController < ApplicationController
  layout "application"

  def index
    notifications = current_user.notifications.includes(:organization)

    # Read/unread filter
    case params[:read_status].to_s
    when "unread"
      notifications = notifications.unread
    when "read"
      notifications = notifications.read
    end

    # Organization "type-to-filter" (debounced submit in the view)
    if params[:organization_search].present?
      term = "%#{Notification.sanitize_sql_like(params[:organization_search].to_s.strip)}%"
      notifications = notifications.joins(:organization).where("organizations.name ILIKE ?", term)
    end

    # Sorting
    case params[:sort].to_s
    when "oldest"
      notifications = notifications.order(created_at: :asc)
    else
      notifications = notifications.order(created_at: :desc)
    end

    @notifications = notifications
    @unread_count = current_user.notifications.unread.count
  end

  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.json { render json: { success: true, unread_count: current_user.notifications.unread.count } }
      format.turbo_stream
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn("NotificationsController#mark_as_read not found: user_id=#{current_user.id} id=#{params[:id]}")
    head :not_found
  rescue => e
    Rails.logger.error("NotificationsController#mark_as_read failed: user_id=#{current_user.id} id=#{params[:id]} error=#{e.class}:#{e.message}")
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  def mark_all_as_read
    notification_ids = current_user.notifications.unread.pluck(:id)
    current_user.notifications.unread.update_all(read: true, read_at: Time.current)

    # Reload notifications to get updated state
    notifications = Notification.where(id: notification_ids)

    # Broadcast updates for all notifications
    notifications.each do |notification|
      notification = notification.reload

      # Bell dropdown: remove the item entirely (unread list only).
      notification.broadcast_remove_to(
        "user_#{current_user.id}_notifications",
        target: "bell_notification_#{notification.id}"
      )

      # Inbox: update the item so the "Mark as read" button disappears.
      notification.broadcast_replace_to(
        "user_#{current_user.id}_notifications",
        target: "notification_#{notification.id}",
        partial: "notifications/notification_item",
        locals: { notification: notification }
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
  rescue => e
    Rails.logger.error("NotificationsController#mark_all_as_read failed: user_id=#{current_user.id} error=#{e.class}:#{e.message}")
    respond_to do |format|
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      format.turbo_stream { head :unprocessable_entity }
    end
  end

  def unread_count
    render json: { count: current_user.notifications.unread.count }
  end
end
