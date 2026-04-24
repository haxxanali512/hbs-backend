module ReferralPartners
  class PayoutHistoryPolicy < ApplicationPolicy
    def index?
      accessible?("referral_partner", "payout_history", "index")
    end

    def export?
      accessible?("referral_partner", "payout_history", "export")
    end
  end
end
