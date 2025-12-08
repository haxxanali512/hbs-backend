class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Send error notifications for job failures
  rescue_from StandardError, with: :handle_job_error

  private

  def handle_job_error(exception)
    # Send error notification email
    ErrorNotificationService.notify(
      exception,
      request: nil,
      context: {
        job_class: self.class.name,
        job_id: job_id,
        arguments: arguments
      }
    )

    # Re-raise to let ActiveJob handle retries/discarding
    raise exception
  end
end
