class OrganizationDirectActivationService
  attr_reader :organization, :activated_by, :errors

  def initialize(organization:, activated_by:)
    @organization = organization
    @activated_by = activated_by
    @errors = []
  end

  def call
    return failure("Organization is already activated") if organization.activated?
    return failure("Organization is discarded") if organization.discarded?

    # Store previous state for audit trail
    previous_status = organization.activation_status

    # Force activation by directly setting the activation_status
    # This bypasses AASM state machine to allow activation from any state
    organization.update_columns(
      activation_status: :activated,
      activation_state_changed_at: Time.current
    )

    # Reload to get updated state
    organization.reload

    # Log the activation in audit trail
    organization.audits.create!(
      action: "update",
      audited_changes: {
        activation_status: [ previous_status, "activated" ]
      },
      user: activated_by,
      comment: "Direct activation by admin (bypassed activation workflow)"
    )

    # Send notification to organization owner
    NotificationService.notify_organization_activated(organization)

    success
  rescue => e
    Rails.logger.error("OrganizationDirectActivationService failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    failure("Failed to activate organization: #{e.message}")
  end

  def success?
    errors.empty?
  end

  private

  def success
    { success: true, organization: organization }
  end

  def failure(message)
    errors << message
    { success: false, errors: errors, organization: organization }
  end
end
