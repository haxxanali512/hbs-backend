# Mailer to notify organization when Waystar EDI submissions fail
class WaystarSubmissionFailureMailer < ApplicationMailer
  default from: "noreply@hbsdata.com"

  def notify_failures(organization:, results:)
    @organization = organization
    @results = results
    @failed_count = results[:failed].size
    @successful_count = results[:successful].size
    @super_admin_emails = User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)

    # Send to organization owner and super admins
    recipients = [ organization.owner.email ] + @super_admin_emails
    recipients = recipients.uniq.compact

    return if recipients.empty?

    mail(
      to: recipients,
      subject: "[Waystar EDI Submission Failure] #{@failed_count} encounter(s) failed for #{@organization.name}"
    )
  end
end
