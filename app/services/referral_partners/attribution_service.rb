module ReferralPartners
  class AttributionService
    def self.call(organization:, referral_code: nil)
      new(organization:, referral_code:).call
    end

    def initialize(organization:, referral_code:)
      @organization = organization
      @referral_code = referral_code.presence || organization.referral_code
    end

    def call
      return nil if referral_code.blank?

      partner = ::ReferralPartner.active_for_attribution.find_by(referral_code: referral_code)
      return nil unless partner

      relationship = ReferralRelationship.find_or_initialize_by(
        referral_partner: partner,
        referred_org: organization
      )

      relationship.assign_attributes(
        referral_source: "referral_code",
        contract_signed_date: contract_signed_date,
        status: :signed,
        eligibility_status: :pending
      )
      relationship.save!

      NotificationService.notify_referral_attached_to_new_client(relationship)
      relationship
    end

    private

    attr_reader :organization, :referral_code

    def contract_signed_date
      organization.organization_compliance&.contract_accepted_at&.to_date || Date.current
    end
  end
end
