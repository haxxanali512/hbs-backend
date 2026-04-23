class ReferralPartners::BaseController < ApplicationController
  before_action :ensure_referral_partner_access
  before_action :set_referral_portal_context

  private

  def ensure_referral_partner_access
    return if current_user&.has_referral_partner_access? && current_user&.referral_partner.present?

    redirect_to fallback_access_denied_path, alert: "Access denied. Referral partner access is required.", allow_other_host: true
  end

  def current_referral_partner
    @current_referral_partner ||= current_user.referral_partner
  end
  helper_method :current_referral_partner

  def set_referral_portal_context
    @current_organization = nil
    session[:portal_context] = "referral_partner"
  end

  def fallback_access_denied_path
    return portal_contexts_path if current_user&.multiple_portal_contexts?

    portal_context_path_for(current_user&.default_portal_context || :tenant, user: current_user)
  end
end
