lock "~> 3.19.1"

set :application, "hbs-backend"
# set :stage, :production
set :repo_url, "git@github.com:haxxanali512/hbs-backend.git"

set :use_sudo, true
set :keep_releases, 5
set :pm2_app_name, "hbs-backend"    # Name of your application in PM2
set :pm2_bin, "/usr/local/bin/pm2"
set :sidekiq_roles, :sidekiq
set :log_level, :debug
set :pty, false
set :ssh_options, {
  keys: %w[~/.ssh/id_rsa],
  forward_agent: true,
  auth_methods: %w[publickey]
}
set :deploy_to, "/home/deployer/www/hbs-backend"
set :sidekiq_service_unit_name, "hbs-backend-sidekiq"
# Linked files: credentials key is stage-specific (staging.key vs production.key); others are per-server.
append :linked_files,
  "config/database.yml",
  "config/puma.rb",
  "config/sidekiq.yml",
  "config/docusign_private_key.pem"

set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle]
set :pm2_start_command, "bundle exec rails server -e #{fetch(:stage)}"
set :rvm1_ruby_version, "3.2.0"
set :rvm_type, :user
set :default_env, { rvm_bin_path: "~/.rvm/bin" }
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w[rake gem bundle ruby]).uniq }

# Bundler configuration for platform-specific gems
set :bundle_flags, "--quiet"
set :bundle_without, %w[development test].join(" ")
set :bundle_jobs, 4

puts "STAGE IS: #{fetch(:stage)}"
puts "RAILS_ENV IS: #{fetch(:rails_env)}"
puts "RACK_ENV IS: #{fetch(:rack_env)}"


# Sidekiq configuration
set :sidekiq_roles, :worker
set :sidekiq_env, fetch(:rack_env, fetch(:rails_env, fetch(:stage)))
set :sidekiq_log, -> { File.join(shared_path, "log", "sidekiq.log") }
set :sidekiq_pid, -> { File.join(shared_path, "tmp", "pids", "sidekiq.pid") }
set :sidekiq_cmd, "bundle exec sidekiq"
set :sidekiq_systemctl_user, :user # ensures systemd runs under deployer
set :sidekiq_config, -> { File.join(current_path, "config", "sidekiq.yml") }
set :sidekiq_require, -> { File.join(current_path, "config", "environment.rb") }

set :puma_bind, "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_conf, "#{shared_path}/puma.rb"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{shared_path}/log/puma_access.log"
set :puma_error_log, "#{shared_path}/log/puma_error.log"
set :puma_role, :app
set :puma_env, fetch(:rack_env, fetch(:rails_env, fetch(:stage)))
set :puma_threads, [ 4, 16 ]
set :puma_workers, 2
set :puma_worker_timeout, nil
set :puma_init_active_record, true

# Deployment tracking for Sidekiq 7+
set :sidekiq_mark_deploy, true
set :sidekiq_deploy_label, -> { "#{fetch(:stage)}-#{fetch(:current_revision, "unknown")[0..6]}" }

# set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
# set :sidekiq_monit_use_sudo, true
namespace :deploy do
  desc "Upload required config files for the current stage"
  task :upload_configs do
    on roles(:all) do
      stage = fetch(:stage)
      execute :mkdir, "-p", "#{deploy_to}/shared/config/credentials"
      upload!("config/credentials/#{stage}.key", "#{deploy_to}/shared/config/credentials/#{stage}.key")
      upload!("config/credentials/#{stage}.yml.enc", "#{deploy_to}/shared/config/credentials/#{stage}.yml.enc")
      upload!("config/database.yml", "#{deploy_to}/shared/config/database.yml")
    end
  end

  desc "Seeds database"
  task :seed do
    on roles(:app) do
      within "#{fetch(:deploy_to)}/current/" do
        execute :bundle, :exec, :"rake db:seed RAILS_ENV=#{fetch(:stage)}"
      end
    end
  end
end

# namespace :credentials do
#   desc "Fix credentials key symlink in current release (stage-specific: staging.key or production.key)"
#   task :fix_symlink do
#     on release_roles(:all) do
#       stage = fetch(:stage)
#       key_file = "config/credentials/#{stage}.key"
#       execute :mkdir, "-p", "#{current_path}/config/credentials"
#       execute :ln, "-sf", "#{shared_path}/#{key_file}", "#{current_path}/#{key_file}"
#       info "Symlinked #{key_file}"
#     end
#   end

#   desc "Upload current stage credentials .yml.enc to server (e.g. staging.yml.enc or production.yml.enc)"
#   task :push_encrypted do
#     on roles(:all) do
#       stage = fetch(:stage)
#       source_file = "config/credentials/#{stage}.yml.enc"
#       target_file = "#{shared_path}/config/credentials/#{stage}.yml.enc"

#       unless File.exist?(source_file)
#         error "File not found: #{source_file}"
#         exit 1
#       end

#       info "Uploading #{source_file} -> #{target_file}"
#       upload!(source_file, target_file)
#       info "Uploaded #{stage}.yml.enc"
#     end
#   end
# end
