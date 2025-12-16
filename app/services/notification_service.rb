# Service for creating in-app notifications
class NotificationService
  class << self
    # Create a notification for organization-related actions
    def notify_organization_action(user:, organization:, action_type:, title:, message:, action_url: nil, metadata: {})
      Notification.create!(
        user: user,
        organization: organization,
        notification_type: action_type,
        title: title,
        message: message,
        action_url: action_url,
        metadata: metadata
      )
    end

    # Notify organization owner when admin creates organization
    def notify_organization_created(organization)
      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:organization_created],
        title: "Organization Created",
        message: "Your organization '#{organization.name}' has been created. Please complete the activation process.",
        action_url: "/tenant/activation"
      )
    end

    # Notify organization owner when admin updates organization
    def notify_organization_updated(organization, changes = {})
      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:organization_updated],
        title: "Organization Updated",
        message: "Your organization '#{organization.name}' has been updated by an administrator.",
        action_url: "/tenant/dashboard",
        metadata: { changes: changes }
      )
    end

    # Notify organization owner when admin activates organization
    def notify_organization_activated(organization)
      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:organization_activated],
        title: "Organization Activated",
        message: "Your organization '#{organization.name}' has been activated and is now fully operational.",
        action_url: "/tenant/dashboard"
      )
    end

    # Notify organization owner when admin suspends organization
    def notify_organization_suspended(organization, reason: nil)
      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:organization_suspended],
        title: "Organization Suspended",
        message: "Your organization '#{organization.name}' has been suspended. Please contact support for more information.",
        action_url: "/tenant/dashboard",
        metadata: { reason: reason }
      )
    end

    # Notify organization owner when admin deletes organization
    def notify_organization_deleted(organization_name, owner_email)
      user = User.find_by(email: owner_email)
      return unless user

      Notification.create!(
        user: user,
        organization: nil,
        notification_type: Notification::NOTIFICATION_TYPES[:organization_deleted],
        title: "Organization Deleted",
        message: "Your organization '#{organization_name}' has been deleted.",
        action_url: nil
      )
    end

    # Notify organization owner when billing is approved
    def notify_billing_approved(organization_billing)
      notify_organization_action(
        user: organization_billing.organization.owner,
        organization: organization_billing.organization,
        action_type: Notification::NOTIFICATION_TYPES[:billing_approved],
        title: "Payment Approved",
        message: "Your manual payment request for #{organization_billing.organization.name} has been approved.",
        action_url: "/tenant/organization_billings"
      )
    end

    # Notify organization owner when billing is rejected
    def notify_billing_rejected(organization_billing, reason: nil)
      notify_organization_action(
        user: organization_billing.organization.owner,
        organization: organization_billing.organization,
        action_type: Notification::NOTIFICATION_TYPES[:billing_rejected],
        title: "Payment Rejected",
        message: "Your manual payment request for #{organization_billing.organization.name} has been rejected.#{reason ? " Reason: #{reason}" : ""}",
        action_url: "/tenant/organization_billings",
        metadata: { reason: reason }
      )
    end

    # Notify organization when provider is approved
    def notify_provider_approved(provider, organization)
      return unless organization&.owner

      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:provider_approved],
        title: "Provider Approved",
        message: "Provider #{provider.full_name} has been approved and is now active.",
        action_url: "/tenant/providers/#{provider.id}"
      )
    end

    # Notify organization when provider is rejected
    def notify_provider_rejected(provider, organization, reason: nil)
      return unless organization&.owner

      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:provider_rejected],
        title: "Provider Rejected",
        message: "Provider #{provider.full_name} has been rejected.#{reason ? " Reason: #{reason}" : ""}",
        action_url: "/tenant/providers/#{provider.id}",
        metadata: { reason: reason }
      )
    end

    # Notify organization when provider is suspended
    def notify_provider_suspended(provider, organization, reason: nil)
      return unless organization&.owner

      notify_organization_action(
        user: organization.owner,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:provider_suspended],
        title: "Provider Suspended",
        message: "Provider #{provider.full_name} has been suspended.#{reason ? " Reason: #{reason}" : ""}",
        action_url: "/tenant/providers/#{provider.id}",
        metadata: { reason: reason }
      )
    end

    # Notify user when they are invited
    def notify_user_invited(user, organization)
      notify_organization_action(
        user: user,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:user_invited],
        title: "Invitation Received",
        message: "You have been invited to join #{organization.name}.",
        action_url: "/users/invitation/accept?invitation_token=#{user.raw_invitation_token}"
      )
    end

    # Notify user when their role changes
    def notify_user_role_changed(user, organization, new_role_name)
      notify_organization_action(
        user: user,
        organization: organization,
        action_type: Notification::NOTIFICATION_TYPES[:user_role_changed],
        title: "Role Updated",
        message: "Your role in #{organization.name} has been changed to #{new_role_name}.",
        action_url: "/tenant/dashboard",
        metadata: { new_role: new_role_name }
      )
    end
  end
end
