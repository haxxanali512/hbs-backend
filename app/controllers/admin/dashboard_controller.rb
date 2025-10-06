class Admin::DashboardController < ::ApplicationController
  # before_action :admin_required

  def index
    # Temporarily disable authorization to test session issue
    # authorize [ :admin, :dashboard ]

    # Debug session information
    Rails.logger.info "=== ADMIN DASHBOARD DEBUG ==="
    Rails.logger.info "User signed in?: #{user_signed_in?}"
    Rails.logger.info "Current user: #{current_user&.email}"
    Rails.logger.info "Session ID: #{session.id}"
    Rails.logger.info "Session data: #{session.to_hash}"
    Rails.logger.info "Warden user: #{warden.user&.email}"
    Rails.logger.info "============================="
    @users_count = User.count
    # @active_users_count = User.active_users.count
    # @suspended_users_count = User.suspended_users.count
    @recent_users = User.order(created_at: :desc).limit(5)
    # @recent_sessions = Session.includes(:user).recent.limit(10)
    # @roles_count = Role.count
    # @system_roles_count = Role.system_roles.count
    # @custom_roles_count = Role.custom_roles.count

    # Chart data for user registrations over time
    @user_registrations_data = User.where(created_at: 30.days.ago..Time.current)
                                  .group("DATE(created_at)")
                                  .count

    # Recent activity - temporarily disabled
    # @recent_audit_logs = Audited::Audit.includes(:user, :auditable)
    #                                   .where(auditable_type: "User")
    #                                   .order(created_at: :desc)
    #                                   .limit(10)
  end
end
