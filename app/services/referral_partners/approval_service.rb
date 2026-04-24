module ReferralPartners
  class ApprovalService
    def self.call(referral_partner:, approved_by:)
      new(referral_partner:, approved_by:).call
    end

    def initialize(referral_partner:, approved_by:)
      @referral_partner = referral_partner
      @approved_by = approved_by
    end

    def call
      ActiveRecord::Base.transaction do
        user = find_or_build_user
        user.role = role_with_referral_access_for(user)
        user.save! if user.new_record?
        user.save! if user.changed?

        code = referral_partner.referral_code.presence || CodeGenerator.call
        referral_partner.update!(
          user: user,
          status: :approved,
          approved_at: Time.current,
          referral_code: code,
          referral_url: referral_url_for(code)
        )

        invite_user_if_needed(user)
        NotificationService.notify_referral_partner_application_approved(referral_partner, user: user, approved_by: approved_by)
      end
    end

    private

    attr_reader :referral_partner, :approved_by

    def find_or_build_user
      User.find_or_initialize_by(email: referral_partner.email.downcase.strip).tap do |user|
        user.first_name ||= referral_partner.first_name
        user.last_name ||= referral_partner.last_name
        user.username ||= referral_partner.email.split("@").first
        user.password ||= Devise.friendly_token.first(20) if user.encrypted_password.blank?
        user.status ||= :pending
      end
    end

    def role_with_referral_access_for(user)
      return user.role if role_has_referral_access?(user.role)
      return default_referral_role if user.role.blank?

      composite_name = "#{user.role.role_name} + Referral Partner"
      composite_role = Role.find_or_initialize_by(role_name: composite_name, scope: user.role.scope)
      composite_role.access = merged_access(user.role.access)
      composite_role.save! if composite_role.new_record? || composite_role.changed?
      composite_role
    end

    def default_referral_role
      Role.where(scope: :referral).detect { |role| role_has_referral_access?(role) } ||
        Role.where(scope: :tenant).detect { |role| role_has_referral_access?(role) } ||
        create_default_referral_role
    end

    def create_default_referral_role
      Role.create!(
        role_name: "Referral Partner",
        scope: :referral,
        access: merged_access({})
      )
    end

    def merged_access(existing_access)
      access = (existing_access || {}).deep_dup
      access["referral_partner"] = enable_permissions(HbsCustoms::ModulePermission.data[:referral_partner])
      access
    end

    def enable_permissions(hash)
      hash.each_with_object({}) do |(key, value), acc|
        acc[key.to_s] = value.is_a?(Hash) ? enable_permissions(value) : true
      end
    end

    def role_has_referral_access?(role)
      role&.access&.dig("referral_partner", "dashboard", "index") == true
    end

    def invite_user_if_needed(user)
      return if user.invitation_sent_at.present?
      return if user.persisted? && user.encrypted_password.present? && !user.pending?

      user.invite!
    end

    def referral_url_for(code)
      base_host = ENV["HOST"].presence || "holisticbusinessolution.net"
      host = base_host.to_s.sub(%r{\Ahttps?://}, "")
      host = host.split(".").drop(1).join(".") if host.split(".").length >= 3 && %w[admin www referral].include?(host.split(".").first)
      protocol = host.include?("localhost") ? "http" : "https"
      "#{protocol}://referral.#{host}/apply?ref=#{code}"
    end
  end
end
