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

    # Notify super admins when a tenant submits encounters for billing
    def notify_encounters_submitted_for_billing(organization:, encounter_count:)
      # Find all super admin users (include active, pending, or nil status - exclude only inactive and discarded)
      super_admins = User.joins(:role)
                        .where(roles: { role_name: "Super Admin" })
                        .where("status IS NULL OR status != ?", User.statuses[:inactive])
                        .kept # Exclude discarded users

      if super_admins.empty?
        Rails.logger.warn "No super admin users found to notify about encounters submission"
        return
      end

      Rails.logger.info "Notifying #{super_admins.count} super admin(s) about #{encounter_count} encounter(s) submission from #{organization.name}"

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:encounters_submitted_for_billing],
          title: "Encounters Submitted for Billing",
          message: "#{organization.name} has submitted #{encounter_count} encounter(s) for billing.",
          action_url: "/admin/encounters?organization_id=#{organization.id}&submitted_filter=submitted",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            encounter_count: encounter_count
          }
        )
        Rails.logger.info "Notification created for super admin: #{admin.email}"
      end
    end

    # Notify super admins when a tenant requests a claim void for a billed encounter
    def notify_claim_void_requested(organization:, encounter:, requested_by:, support_ticket:)
      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      return if super_admins.empty?

      patient_name = encounter.patient&.full_name || "Unknown Patient"
      dos = encounter.date_of_service&.strftime("%m/%d/%Y") || "—"

      title = "Claim Void Requested"
      message = "Claim Void Requested — #{patient_name} — DOS #{dos} — #{organization.name}"

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:claim_void_requested],
          title: title,
          message: message,
          action_url: "/admin/support_tickets/#{support_ticket.id}",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            encounter_id: encounter.id,
            patient_id: encounter.patient_id,
            provider_id: encounter.provider_id,
            date_of_service: encounter.date_of_service,
            requested_by_user_id: requested_by.id,
            support_ticket_id: support_ticket.id
          }
        )
      end
    end

    # Notify super admins the first time a provider has encounters submitted for billing
    def notify_first_encounter_submitted_for_provider(provider:, organization:)
      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      return if super_admins.empty?

      title = "First Encounter Submitted for New Provider — #{provider.full_name}"
      message = "#{organization.name} submitted the first encounter(s) for #{provider.full_name}."

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:first_encounter_submitted_for_provider],
          title: title,
          message: message,
          action_url: "/admin/encounters?provider_id=#{provider.id}&organization_id=#{organization.id}&submitted_filter=submitted",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            provider_id: provider.id
          }
        )
      end
    end

    # Notify super admins when an organization accepts a plan that needs enrollment verification
    def notify_org_accepted_plan_needs_enrollment(org_accepted_plan)
      organization = org_accepted_plan.organization
      return unless organization

      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      if super_admins.empty?
        Rails.logger.warn "No super admin users found to notify about org accepted plan enrollment verification"
        return
      end

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:org_accepted_plan_needs_enrollment],
          title: "Plan Accepted – Enrollment Verification Needed",
          message: "Organization #{organization.name} accepted plan #{org_accepted_plan.insurance_plan.name}. Please verify enrollment and update the enrollment status.",
          action_url: "/admin/org_accepted_plans/#{org_accepted_plan.id}",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            org_accepted_plan_id: org_accepted_plan.id,
            insurance_plan_id: org_accepted_plan.insurance_plan_id
          }
        )
      end
    end

    # Notify super admins when a payer enrollment is created and needs verification
    def notify_payer_enrollment_needs_verification(payer_enrollment)
      organization = payer_enrollment.organization
      return unless organization

      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      if super_admins.empty?
        Rails.logger.warn "No super admin users found to notify about payer enrollment verification"
        return
      end

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:payer_enrollment_needs_verification],
          title: "Payer Enrollment Needs Verification",
          message: "Organization #{organization.name} created a payer enrollment with #{payer_enrollment.payer.name}. Please verify and update the enrollment status.",
          action_url: "/admin/payer_enrollments/#{payer_enrollment.id}",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            payer_enrollment_id: payer_enrollment.id,
            payer_id: payer_enrollment.payer_id,
            provider_id: payer_enrollment.provider_id,
            enrollment_type: payer_enrollment.enrollment_type,
            status: payer_enrollment.status
          }
        )
      end
    end

    # Notify super admins when a provider is submitted for approval
    def notify_provider_submitted(provider)
      organization = provider.organizations.first
      return unless organization

      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      if super_admins.empty?
        Rails.logger.warn "No super admin users found to notify about provider submission"
        return
      end

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:provider_submitted],
          title: "Provider Submitted for Approval",
          message: "Organization #{organization.name} submitted provider #{provider.full_name} for HBS approval.",
          action_url: "/admin/providers/#{provider.id}",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            provider_id: provider.id
          }
        )
      end
    end

    # Notify super admins when a provider is resubmitted for approval
    def notify_provider_resubmitted(provider)
      organization = provider.organizations.first
      return unless organization

      super_admins = User.joins(:role)
                         .where(roles: { role_name: "Super Admin" })
                         .where("status IS NULL OR status != ?", User.statuses[:inactive])
                         .kept

      if super_admins.empty?
        Rails.logger.warn "No super admin users found to notify about provider resubmission"
        return
      end

      super_admins.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:provider_resubmitted],
          title: "Provider Resubmitted for Approval",
          message: "Organization #{organization.name} resubmitted provider #{provider.full_name} for HBS approval.",
          action_url: "/admin/providers/#{provider.id}",
          metadata: {
            organization_id: organization.id,
            organization_name: organization.name,
            provider_id: provider.id
          }
        )
      end
    end

    # =========================
    # Encounter comment notifications
    # =========================

    def notify_encounter_comment_from_hbs(comment)
      encounter = comment.encounter
      organization = comment.organization
      return unless encounter && organization

      patient_name = comment.patient&.full_name || "Patient"
      dos = encounter.date_of_service&.strftime("%m/%d/%Y") || "—"
      title = "New Encounter Comment — #{patient_name} — DOS #{dos}"

      members = organization.organization_memberships.active.includes(:user).map(&:user).uniq
      members.each do |user|
        action_url = "/tenant/encounters/#{encounter.id}"
        Notification.create!(
          user: user,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:encounter_comment_from_hbs],
          title: title,
          message: "#{comment.author.display_name} commented on this encounter.",
          action_url: action_url,
          metadata: {
            encounter_id: encounter.id,
            patient_id: comment.patient_id,
            organization_id: organization.id
          }
        )
        send_encounter_comment_email(recipient: user, comment: comment, portal_url: tenant_portal_url_for(organization, action_url))
      end
    end

    def notify_encounter_comment_from_tenant(comment)
      encounter = comment.encounter
      organization = comment.organization
      return unless encounter && organization

      patient_name = comment.patient&.full_name || "Patient"
      dos = encounter.date_of_service&.strftime("%m/%d/%Y") || "—"
      preview = comment.body_text.to_s.squish.truncate(120)
      title = "Encounter Comment — #{patient_name} — DOS #{dos}"
      message = "#{organization.name} commented: #{preview.presence || 'New comment added.'}"

      recipients = User
        .joins(:role)
        .where(roles: { scope: Role.scopes[:global] })
        .where("users.status IS NULL OR users.status != ?", User.statuses[:inactive])
        .kept
        .includes(:role)
        .select(&:has_admin_access?)
        .reject { |u| u.id == comment.author_user_id }
        .uniq(&:id)

      recipients.each do |admin|
        action_url = "/admin/encounters/#{encounter.id}"
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:encounter_comment_from_tenant],
          title: title,
          message: message,
          action_url: action_url,
          metadata: {
            encounter_id: encounter.id,
            patient_id: comment.patient_id,
            organization_id: organization.id,
            date_of_service: encounter.date_of_service,
            comment_id: comment.id,
            comment_preview: preview
          }
        )
        send_encounter_comment_email(recipient: admin, comment: comment, portal_url: admin_portal_url_for(action_url))
      end
    end

    # =========================
    # Support ticket comment notifications
    # =========================

    def notify_support_ticket_created_from_tenant(ticket)
      organization = ticket.organization
      return unless ticket && organization

      title = "New Support Ticket Submitted — #{ticket.subject}"
      message = "Tenant #{organization.name} submitted a new support ticket."

      recipients =
        if ticket.assigned_to_user&.hbs_user?
          [ ticket.assigned_to_user ]
        else
          User.joins(:role)
              .where(roles: { role_name: "Super Admin" })
              .where("status IS NULL OR status != ?", User.statuses[:inactive])
              .kept
        end

      recipients.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:support_ticket_created_from_tenant],
          title: title,
          message: message,
          action_url: "/admin/support_tickets/#{ticket.id}",
          metadata: {
            support_ticket_id: ticket.id,
            organization_id: organization.id
          }
        )
      end
    end

    def notify_support_ticket_assigned(ticket, assignee:, assigned_by:)
      organization = ticket.organization
      return unless ticket && organization && assignee

      Notification.create!(
        user: assignee,
        organization: organization,
        notification_type: Notification::NOTIFICATION_TYPES[:support_ticket_assigned],
        title: "Support Ticket Assigned — #{ticket.subject}",
        message: "#{assigned_by&.display_name || 'An admin'} assigned you support ticket ##{ticket.id}.",
        action_url: "/admin/support_tickets/#{ticket.id}",
        metadata: {
          support_ticket_id: ticket.id,
          organization_id: organization.id,
          assigned_by_user_id: assigned_by&.id
        }
      )
    end

    def notify_support_ticket_comment_from_hbs(comment)
      ticket = comment.support_ticket
      organization = ticket.organization
      recipient = ticket.created_by_user
      return unless ticket && organization && recipient&.client_user?

      title = "New Support Ticket Reply — #{ticket.subject}"
      message = "#{comment.author_user.display_name} replied to your support ticket."

      Notification.create!(
        user: recipient,
        organization: organization,
        notification_type: Notification::NOTIFICATION_TYPES[:support_ticket_comment_from_hbs],
        title: title,
        message: message,
        action_url: "/tenant/support_tickets/#{ticket.id}",
        metadata: {
          support_ticket_id: ticket.id,
          organization_id: organization.id
        }
      )
    end

    def notify_support_ticket_comment_from_tenant(comment)
      ticket = comment.support_ticket
      organization = ticket.organization
      return unless ticket && organization

      title = "Tenant Replied to Support Ticket — #{ticket.subject}"
      message = "Tenant #{organization.name} replied on support ticket."

      recipients =
        if ticket.assigned_to_user&.hbs_user?
          [ ticket.assigned_to_user ]
        else
          User.joins(:role)
              .where(roles: { role_name: "Super Admin" })
              .where("status IS NULL OR status != ?", User.statuses[:inactive])
              .kept
        end

      recipients.each do |admin|
        Notification.create!(
          user: admin,
          organization: organization,
          notification_type: Notification::NOTIFICATION_TYPES[:support_ticket_comment_from_tenant],
          title: title,
          message: message,
          action_url: "/admin/support_tickets/#{ticket.id}",
          metadata: {
            support_ticket_id: ticket.id,
            organization_id: organization.id
          }
        )
      end
    end

    # =========================
    # Password reset notifications
    # =========================

    def notify_password_reset_requested(user)
      Notification.create!(
        user: user,
        organization: nil,
        notification_type: Notification::NOTIFICATION_TYPES[:password_reset_requested],
        title: "Password reset requested",
        message: "A password reset was requested for your account. If this wasn't you, please contact support.",
        action_url: "/users/password/edit",
        metadata: {}
      )
    end

    def notify_password_reset_completed(user)
      Notification.create!(
        user: user,
        organization: nil,
        notification_type: Notification::NOTIFICATION_TYPES[:password_reset_completed],
        title: "Your password was reset",
        message: "Your password was changed successfully.",
        action_url: "/",
        metadata: {}
      )
    end

    def send_encounter_comment_email(recipient:, comment:, portal_url:)
      return unless recipient&.email.present?

      EncounterCommentMailer.with(
        recipient: recipient,
        comment: comment,
        portal_url: portal_url
      ).encounter_comment_added.deliver_later
    rescue => e
      Rails.logger.error("Failed to send encounter comment email to #{recipient&.email}: #{e.message}")
    end

    def tenant_portal_url_for(organization, path)
      host = base_portal_host
      protocol = portal_protocol_for(host)
      "#{protocol}://#{organization.subdomain}.#{host}#{path}"
    end

    def admin_portal_url_for(path)
      host = base_portal_host
      protocol = portal_protocol_for(host)
      "#{protocol}://#{host}#{path}"
    end

    def base_portal_host
      mailer_options = Rails.application.config.action_mailer.default_url_options || {}
      routes_options = Rails.application.routes.default_url_options || {}

      configured_host = ENV["DOMAIN"].presence ||
                        ENV["HOST"].presence ||
                        mailer_options[:host].presence ||
                        routes_options[:host].presence
      configured_port = mailer_options[:port].presence || routes_options[:port].presence

      host = configured_host.to_s.sub(%r{\Ahttps?://}, "").split("/").first
      if host.blank?
        return "localhost:3000" if Rails.env.development? || Rails.env.test?
        return "holisticbusinesssolution.com"
      end

      host_parts = host.split(".")
      normalized_host = if host_parts.length >= 3 && %w[www admin].include?(host_parts.first)
                          host_parts.drop(1).join(".")
      else
                          host
      end

      if configured_port.present? && normalized_host.exclude?(":")
        "#{normalized_host}:#{configured_port}"
      else
        normalized_host
      end
    end

    def portal_protocol_for(host)
      explicit_protocol = ENV["APP_PROTOCOL"].presence
      return explicit_protocol if explicit_protocol.present?

      host.include?("localhost") ? "http" : "https"
    end
  end
end
