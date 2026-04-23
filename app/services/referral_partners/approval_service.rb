module ReferralPartners
  class ApprovalService
    def self.call(referral_partner:, invited_by:)
      new(referral_partner:, invited_by:).call
    end

    def initialize(referral_partner:, invited_by:)
      @referral_partner = referral_partner
      @invited_by = invited_by
    end

    def call
      ActiveRecord::Base.transaction do
        partner_user = find_or_initialize_user
        partner_user.save! if partner_user.new_record?

        RoleAssignmentService.call(user: partner_user)
        code = referral_partner.referral_code.presence || CodeGenerator.generate

        referral_partner.update!(
          user: partner_user,
          referral_code: code,
          referral_url: referral_url_for(code),
          status: :approved,
          approved_at: Time.current
        )

        invite_user_if_needed(partner_user)
        NotificationService.notify_referral_partner_application_approved(referral_partner, invited_by: invited_by)
      end

      referral_partner
    end

    private

    attr_reader :referral_partner, :invited_by

    def find_or_initialize_user
      User.find_or_initialize_by(email: referral_partner.email.downcase.strip).tap do |user|
        user.first_name ||= referral_partner.first_name
        user.last_name ||= referral_partner.last_name
        user.username ||= referral_partner.email.split("@").first
        user.password ||= Devise.friendly_token.first(20) if user.encrypted_password.blank?
        user.status ||= :pending
      end
    end

    def invite_user_if_needed(user)
      return if user.invitation_sent_at.present?

      user.invite!
    end

    def referral_url_for(code)
      host = ENV["HOST"].presence || "holisticbusinesssolutions.com"
      "https://referral.#{host}/applications/new?ref=#{code}"
    end
  end
end
