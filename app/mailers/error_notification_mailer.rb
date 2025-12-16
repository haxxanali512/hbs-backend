require "digest"
require "socket"

class ErrorNotificationMailer < ApplicationMailer
  default from: ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@hbsdata.com")

  def notify_error(exception, request_details = {})
    @exception = exception
    @request_details = request_details
    @full_backtrace = exception.backtrace || []
    @backtrace = @full_backtrace.first(50) # Show first 50 lines in email
    @backtrace_count = @full_backtrace.count
    @exception_cause = exception.cause if exception.respond_to?(:cause) && exception.cause
    @environment = Rails.env
    @timestamp = Time.current
    @error_fingerprint = generate_error_fingerprint(exception)
    @system_info = gather_system_info

    recipients = error_notification_recipients
    return if recipients.empty?

    mail(
      to: recipients,
      subject: "[#{@environment.upcase}] Error: #{exception.class.name} - #{truncate_message(exception.message)}"
    )
  end

  private

  def error_notification_recipients
    emails = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip).reject(&:blank?)
    emails.presence || []
  end

  def truncate_message(message, max_length = 100)
    return "No message" if message.blank?
    message.length > max_length ? "#{message[0..max_length]}..." : message
  end

  def generate_error_fingerprint(exception)
    # Create a unique fingerprint for this error type/location
    # This helps identify recurring errors
    key_parts = [
      exception.class.name,
      exception.message&.split("\n")&.first, # First line of message
      @full_backtrace&.first(3)&.join("|") # First 3 backtrace lines
    ].compact.join("|")

    Digest::MD5.hexdigest(key_parts)
  end

  def gather_system_info
    {
      ruby_version: RUBY_VERSION,
      rails_version: Rails.version,
      environment: Rails.env,
      hostname: get_hostname,
      pid: Process.pid,
      memory_usage: get_memory_usage
    }
  rescue => e
    { error: "Failed to gather system info: #{e.message}" }
  end

  def get_hostname
    Socket.gethostname
  rescue
    "unknown"
  end

  def get_memory_usage
    # Try to get memory usage if available (platform dependent)
    begin
      if defined?(GetProcessMem)
        mem = GetProcessMem.new
        "#{(mem.mb).round(2)} MB"
      elsif File.exist?("/proc/#{Process.pid}/status")
        # Linux: read from /proc
        status = File.read("/proc/#{Process.pid}/status")
        if status =~ /VmRSS:\s+(\d+)\s+kB/
          "#{($1.to_i / 1024.0).round(2)} MB"
        else
          "N/A"
        end
      else
        "N/A"
      end
    rescue
      "N/A"
    end
  end
end
