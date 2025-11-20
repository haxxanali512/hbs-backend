lock "~> 3.19.1"

set :application, "hbs-backend"
set :stage, :production
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
set :linked_files, %w[config/credentials/production.key config/database.yml config/puma.rb config/sidekiq.yml config/docusign_private_key.pem]
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle]
set :pm2_start_command, "bundle exec rails server -e production"
set :rvm1_ruby_version, "3.2.0"
set :rvm_type, :user
set :default_env, { rvm_bin_path: "~/.rvm/bin" }
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w[rake gem bundle ruby]).uniq }

# Bundler configuration for platform-specific gems
# Note: --deployment can prevent platform-specific gems from installing
# Use --frozen instead to ensure Gemfile.lock is respected
set :bundle_flags, '--quiet --frozen'
set :bundle_without, %w{development test}.join(' ')
set :bundle_jobs, 4
# Ensure platform-specific gems are installed
set :bundle_binstubs, nil
set :bundle_path, -> { shared_path.join('bundle') }


# Sidekiq configuration
set :sidekiq_roles, :worker
set :sidekiq_env, fetch(:rack_env, fetch(:rails_env, "production"))
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
set :puma_env, fetch(:rack_env, fetch(:rails_env, "production"))
set :puma_threads, [ 4, 16 ]
set :puma_workers, 2
set :puma_worker_timeout, nil
set :puma_init_active_record, true

# Deployment tracking for Sidekiq 7+
set :sidekiq_mark_deploy, true
set :sidekiq_deploy_label, -> { "#{fetch(:stage)}-#{fetch(:current_revision, "unknown")[0..6]}" }

# set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
# set :sidekiq_monit_use_sudo, true

# before "deploy:assets:precompile", "deploy:load_translations"

# Custom task to clear bundle cache and force fresh install
namespace :bundle do
  desc 'Clear bundle cache to force fresh gem installation'
  task :clear_cache do
    on roles(:app) do
      within shared_path do
        execute :rm, '-rf', 'bundle'
      end
    end
  end

  desc 'Ensure platform-specific gems are installed'
  task :ensure_platforms do
    on roles(:app) do
      within release_path do
        # Ensure force_ruby_platform is false to allow platform-specific gems
        execute :bundle, 'config', 'unset', 'force_ruby_platform'
        execute :bundle, 'config', 'set', '--local', 'force_ruby_platform', 'false'
        # Ensure the platform is in the lock file
        execute :bundle, 'lock', '--add-platform', 'x86_64-linux', raise_on_non_zero_exit: false
        
        # Remove the base tailwindcss-ruby gem if it exists (without platform suffix)
        # This forces bundler to install the platform-specific variant
        gem_path = shared_path.join('bundle/ruby/3.2.0/gems')
        base_gem = gem_path.join('tailwindcss-ruby-4.1.16')
        platform_gem = gem_path.join('tailwindcss-ruby-4.1.16-x86_64-linux')
        
        # Remove base gem if platform-specific gem doesn't exist
        if test("[ ! -d #{platform_gem} ]") && test("[ -d #{base_gem} ]")
          info "Removing base tailwindcss-ruby gem to force platform-specific installation"
          execute :rm, '-rf', base_gem
        end
        
        # Install with all platforms to ensure platform-specific gems are installed
        execute :bundle, 'install', '--frozen', '--quiet', '--without', 'development test'
        
        # Verify the platform-specific gem and executable exist
        if test("[ ! -d #{platform_gem} ]")
          error "Platform-specific tailwindcss-ruby gem not found at #{platform_gem}"
          raise "Failed to install tailwindcss-ruby platform-specific gem"
        end
        
        executable_path = platform_gem.join('exe/tailwindcss')
        if test("[ ! -f #{executable_path} ]")
          error "Tailwind CSS executable not found at #{executable_path}"
          raise "Tailwind CSS executable missing in platform-specific gem"
        end
      end
    end
  end
end

# Clear bundle cache before updating code
before 'deploy:updating', 'bundle:clear_cache'
# Ensure platform-specific gems after bundle install
after 'bundler:install', 'bundle:ensure_platforms'

namespace :deploy do
  desc "Uploads required config files"
  task :upload_configs do
    on roles(:all) do
      upload!("config/master.key", "#{deploy_to}/shared/config/credentials/production.key")
      upload!("config/production.yml.enc", "#{deploy_to}/shared/config/credentials/production.yml.enc")
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
