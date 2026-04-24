# frozen_string_literal: true

class PortalSessionCookieStore < ActionDispatch::Session::CookieStore
  ADMIN_SESSION_KEY = "_hbs_admin_session"
  PORTAL_SESSION_KEY = "_hbs_portal_session"
  ADMIN_SUBDOMAINS = %w[admin www].freeze

  private

  def set_cookie(request, session_id, cookie)
    cookie_jar(request)[session_key_for(request)] = cookie
  end

  def get_cookie(request)
    cookie_jar(request)[session_key_for(request)]
  end

  def session_key_for(request)
    admin_request?(request) ? ADMIN_SESSION_KEY : PORTAL_SESSION_KEY
  end

  def admin_request?(request)
    return true unless request.subdomain.present?

    ADMIN_SUBDOMAINS.include?(request.subdomain.to_s.downcase)
  end
end
