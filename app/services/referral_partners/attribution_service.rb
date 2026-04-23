module ReferralPartners
  class AttributionService
    def self.call(organization:, contract_signed_date: nil, referral_code: nil)
      new(organization:, contract_signed_date:, referral_code:).call
    end

    def initialize(organization:, contract_signed_date:, referral_code:)
      @organization = organization
      @contract_signed_date = contract_signed_date
      @referral_code = referral_code.presence || organization.referral_code
    end

    def call
      return if referral_code.blank?

      partner = ReferralPartner.active_for_referrals.find_by(referral_code: referral_code)
      return if partner.blank?

      relationship = ReferralRelationship.find_or_initialize_by(referral_partner: partner, referred_org: organization)
      relationship.assign_attributes(
        status: :signed,
        eligibility_status: :pending,
        contract_signed_date: effective_contract_signed_date,
        tier_selected: organization.tier,
        referral_source: "referral_code",
        referred_practice_name: organization.name
      )
      relationship.save!

      NotificationService.notify_referral_attached_to_new_client(relationship)
      relationship
    end

    private

    attr_reader :organization, :contract_signed_date, :referral_code

    def effective_contract_signed_date
      contract_signed_date.presence ||
        organization.organization_compliance&.contract_accepted_at&.to_date ||
        Date.current
    end
  end
end
