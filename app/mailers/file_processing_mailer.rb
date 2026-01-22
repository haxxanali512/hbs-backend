class FileProcessingMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  def errors_report(user:, job_id:, error_path:, error_count:)
    @user = user
    @job_id = job_id
    @error_count = error_count
    @error_path = error_path

    attach_error_csv(error_path, job_id)

    recipients = ([ user&.email ] + super_admin_emails).compact.uniq
    return if recipients.empty?

    mail(
      to: recipients,
      subject: "Waystar import completed with #{@error_count} error(s)"
    )
  end

  private

  def attach_error_csv(error_path, job_id)
    return unless error_path.present? && File.exist?(error_path)

    filename = "waystar_import_errors_#{job_id}.csv"
    attachments[filename] = File.read(error_path)
  end

  def super_admin_emails
    User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)
  end
end
