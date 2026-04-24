# frozen_string_literal:true

server "3.129.110.111", user: "deployer", roles: %w[app web worker db]

set :branch, "referral_partner_feature_with_login_fix"
set :stage, :staging
set :rails_env, "staging"
append :linked_files,
  "config/credentials/staging.key",
  "config/credentials/staging.yml.enc"
