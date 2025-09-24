lock "~> 3.19.1"

set :application, "hbs-backend"
set :stage, :production
set :repo_url, "git@github.com:haxxanali512/hbs-backend.git"

set :use_sudo, true
set :deploy_via, :copy
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
set :linked_files, %w[config/master.key config/credentials.yml.enc config/database.yml]
set :linked_dirs, %w[log tmp/pids tmp/cache tmp/sockets vendor/bundle]
set :pm2_start_command, "bundle exec rails server -e production"
set :rvm1_ruby_version, "ruby-3.2.0"
set :rvm_type, :user
set :default_env, { rvm_bin_path: "~/.rvm/bin" }
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w[rake gem bundle ruby]).uniq }

# set :sidekiq_monit_conf_dir, '/etc/monit/conf.d'
# set :sidekiq_monit_use_sudo, true

# before "deploy:assets:precompile", "deploy:load_translations"

namespace :deploy do
  task :start do
    on roles(:app) do
      execute :pm2, "start #{fetch(:pm2_start_command)} --name #{fetch(:pm2_app_name)}"
    end
  end

  task :stop do
    on roles(:app) do
      execute :pm2, "stop #{fetch(:pm2_app_name)}"
    end
  end

  task :restart do
    on roles(:app) do
      execute :pm2, "restart #{fetch(:pm2_app_name)}"
    end
  end
end

namespace :deploy do
  desc "Uploads required config files"
  task :upload_configs do
    on roles(:all) do
      upload!("config/master.key", "#{deploy_to}/shared/config/master.key")
      upload!("config/credentials.yml.enc", "#{deploy_to}/shared/config/credentials.yml.enc")
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
