# Configure session store to allow cross-subdomain access
Rails.application.config.session_store :cookie_store,
  key: "_hbs_data_processing_session",
  domain: Rails.env.development? ? ".hbs.localhost" : :all,
  tld_length: Rails.env.development? ? 2 : 2,
  same_site: :lax,
  secure: Rails.env.production?
