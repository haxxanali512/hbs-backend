# Mailer to notify superadmin when EZClaim submissions fail
class EzclaimSubmissionFailureMailer < ApplicationMailer
  default from: "support@holisticbusinesssolution.com"

  def notify_failures(organization:, results:)
    @organization = organization
    @results = results
    @super_admin_emails = User.joins(:role).where(roles: { role_name: "Super Admin" }).pluck(:email)

    return if @super_admin_emails.empty?

    mail(
      to: @super_admin_emails,
      subject: "[EZClaim Submission Failure] #{@results[:failed].count} encounter(s) failed for #{@organization.name}"
    )
  end
end
