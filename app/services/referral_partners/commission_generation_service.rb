module ReferralPartners
  class CommissionGenerationService
    ELIGIBLE_INVOICE_TYPES = [ "revenue_share_monthly" ].freeze

    def self.call(month: Date.current.prev_month.beginning_of_month)
      new(month:).call
    end

    def initialize(month:)
      @month = month.to_date.beginning_of_month
    end

    def call
      ReferralRelationship.includes(:referred_org, :referral_partner).find_each do |relationship|
        next unless eligible_for_month?(relationship)

        commission = ReferralCommission.find_or_initialize_by(
          referral_relationship: relationship,
          month: month
        )
        commission.assign_attributes(
          eligible_revenue: eligible_revenue_for(relationship),
          commission_percent: ReferralPartner::COMMISSION_PERCENT,
          payout_status: :pending
        )
        commission.save!
        relationship.recalculate_totals!
      end
    end

    private

    attr_reader :month

    def eligible_for_month?(relationship)
      return false unless relationship.within_commission_window?(month)
      return false if relationship.ineligible? || relationship.eligibility_expired? || relationship.eligibility_ineligible?
      return false unless relationship.referred_org.organization_billing&.active?
      return false if delinquent_partner?(relationship.referral_partner)

      true
    end

    def eligible_revenue_for(relationship)
      relationship.referred_org.invoices
                  .where(invoice_type: ELIGIBLE_INVOICE_TYPES.map { |name| Invoice.invoice_types[name] })
                  .where(status: :paid, service_month: month)
                  .sum(:amount_paid)
    end

    def delinquent_partner?(partner)
      return false if partner.linked_client_organization.blank?

      partner.linked_client_organization.invoices
             .where("due_date < ? AND amount_due > 0", 15.days.ago.to_date)
             .where(exception_type: [ Invoice.exception_types[:none], nil ])
             .exists?
    end
  end
end
