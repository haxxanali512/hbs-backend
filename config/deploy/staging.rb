# frozen_string_literal:true

server "3.129.110.111", user: "deployer", roles: %w[app web worker db]

set :branch, "staging"
set :stage, :staging
set :rails_env, "staging"
append :linked_files,
  "config/credentials/staging.key",
  "config/credentials/staging.yml.enc"
