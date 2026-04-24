module ReferralPartners
  class PayoutHistoryController < BaseController
    def index
      @commissions = current_referral_partner.referral_commissions.includes(:referral_relationship).order(month: :desc)
    end

    def export
      commissions = current_referral_partner.referral_commissions.includes(:referral_relationship).order(month: :desc)
      csv = CSV.generate(headers: true) do |rows|
        rows << [ "Month", "Practice Name", "Eligible Revenue", "Commission %", "Commission Amount", "Status", "Paid Date" ]
        commissions.each do |commission|
          rows << [
            commission.month.strftime("%Y-%m"),
            commission.referral_relationship.referred_practice_name,
            commission.eligible_revenue,
            commission.commission_percent,
            commission.commission_amount,
            commission.payout_status,
            commission.payout_date
          ]
        end
      end

      send_data csv, filename: "referral_payout_history_#{Date.current.strftime('%Y%m%d')}.csv", type: "text/csv"
    end
  end
end
