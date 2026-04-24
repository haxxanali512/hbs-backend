# Separate admin from tenant/referral sessions so subdomains do not bleed auth context.
require Rails.root.join("lib/portal_session_cookie_store")

Rails.application.config.session_store PortalSessionCookieStore,
  domain: Rails.env.development? ? ".hbs.localhost" : :all,
  tld_length: Rails.env.development? ? 2 : 2,
  same_site: :lax,
  secure: Rails.env.production?
