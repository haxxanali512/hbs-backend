# frozen_string_literal:true

server "3.148.151.165", user: "deployer", roles: %w[app web worker]

set :branch, "main"
set :stage, :production
set :rails_env, "production"
