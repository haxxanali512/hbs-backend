class ProviderNotificationService
  def self.notify_submission(provider)
    # Web notification only: notify HBS super admins about new provider submission
    NotificationService.notify_provider_submitted(provider)
    Rails.logger.info "Provider submission notification (in-app) sent for #{provider.full_name}"
  end

  def self.notify_approval(provider)
    # Notify organization about provider approval
    OrganizationMailer.provider_approved(provider).deliver_now
    Rails.logger.info "Provider approval notification sent for #{provider.full_name}"
  end

  def self.notify_rejection(provider)
    # Notify organization about provider rejection
    OrganizationMailer.provider_rejected(provider).deliver_now
    Rails.logger.info "Provider rejection notification sent for #{provider.full_name}"
  end

  def self.notify_suspension(provider)
    # Notify organization about provider suspension
    OrganizationMailer.provider_suspended(provider).deliver_now
    Rails.logger.info "Provider suspension notification sent for #{provider.full_name}"
  end

  def self.notify_reactivation(provider)
    # Notify organization about provider reactivation
    OrganizationMailer.provider_reactivated(provider).deliver_now
    Rails.logger.info "Provider reactivation notification sent for #{provider.full_name}"
  end

  def self.notify_resubmission(provider)
    # Web notification only: notify HBS super admins about provider resubmission
    NotificationService.notify_provider_resubmitted(provider)
    Rails.logger.info "Provider resubmission notification (in-app) sent for #{provider.full_name}"
  end

  def self.notify_deactivation(provider)
    # Notify organization about provider deactivation
    OrganizationMailer.provider_deactivated(provider).deliver_now
    Rails.logger.info "Provider deactivation notification sent for #{provider.full_name}"
  end
end
