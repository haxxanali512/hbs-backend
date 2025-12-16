# ErrorNotificationService
#
# Sends email notifications for 500-level server errors, similar to Honeybadger/Sentry.
#
# Configuration (via environment variables):
#   ERROR_NOTIFICATION_EMAILS - Comma-separated list of email addresses to notify
#                                Example: "admin@example.com,dev@example.com"
#   ERROR_NOTIFICATION_FROM - Email address to send from (default: "errors@hbsdata.com")
#   ERROR_NOTIFICATION_IN_DEV - Set to "true" to enable notifications in development
#
# Usage:
#   Automatically triggered for:
#   - 500 errors in controllers (via ApplicationController)
#   - Background job failures (via ApplicationJob)
#
#   Manually trigger:
#   ErrorNotificationService.notify(exception, request: request, context: { user_id: 1 })
#
class ErrorNotificationService
  class << self
    def notify(exception, request: nil, context: {})
      return unless should_notify?(exception)

      request_details = build_request_details(request, context)

      # Send email notification asynchronously to avoid blocking
      ErrorNotificationMailer.notify_error(exception, request_details).deliver_later

      Rails.logger.info "Error notification email queued for #{exception.class.name}"
    rescue => e
      # Don't let notification errors break the app
      Rails.logger.error "Failed to send error notification: #{e.message}"
    end

    private

    def should_notify?(exception)
      # Only notify for 500-level errors in production/staging
      return false if Rails.env.development? && ENV["ERROR_NOTIFICATION_IN_DEV"] != "true"
      return false if exception.is_a?(ActionController::RoutingError) # Skip 404s
      return false if exception.is_a?(ActiveRecord::RecordNotFound) # Skip 404s

      # Check if email recipients are configured
      recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip).reject(&:blank?)
      return false if recipients.empty?

      true
    end

    def build_request_details(request, context)
      if request
        {
          url: request.url,
          method: request.method,
          path: request.path,
          params: sanitize_params(request.params),
          user_agent: request.user_agent,
          ip: request.remote_ip,
          referer: request.referer,
          user_id: context[:user_id],
          organization_id: context[:organization_id],
          request_id: request.request_id
        }
      elsif context[:job_class].present?
        {
          job_class: context[:job_class],
          job_id: context[:job_id],
          arguments: sanitize_job_arguments(context[:arguments])
        }
      else
        {}
      end
    end

    def sanitize_job_arguments(arguments)
      # Limit argument size to avoid huge emails
      return arguments if arguments.blank?

      if arguments.is_a?(Array)
        arguments.map { |arg| arg.is_a?(String) && arg.length > 500 ? "#{arg[0..500]}..." : arg }
      else
        arguments.to_s.length > 500 ? "#{arguments.to_s[0..500]}..." : arguments
      end
    end

    def sanitize_params(params)
      # Remove sensitive data from params
      sanitized = params.to_unsafe_h.dup
      sanitized.delete("password")
      sanitized.delete("password_confirmation")
      sanitized.delete("authenticity_token")
      sanitized.delete("_method")
      sanitized
    end
  end
end
