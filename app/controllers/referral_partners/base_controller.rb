module ReferralPartners
  class BaseController < ApplicationController
    before_action :ensure_referral_partner_access

    helper_method :current_referral_partner

    private

    def ensure_referral_partner_access
      return if current_user&.has_referral_partner_access? && current_referral_partner.present?

      redirect_to portal_destination_for(:tenant) || new_user_session_path, alert: "Referral partner access is required.", allow_other_host: true
    end

    def current_referral_partner
      @current_referral_partner ||= current_user&.referral_partner
    end
  end
end
