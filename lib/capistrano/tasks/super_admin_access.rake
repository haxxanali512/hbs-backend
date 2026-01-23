namespace :super_admin do
  desc "Sync Super Admin role access"
  task :sync_access do
    on roles(:app) do
        within release_path do
          with rails_env: fetch(:rails_env, fetch(:stage)) do
            execute :bundle, :exec, :rails, "runner", "AdminAccessService.new.sync_super_admin_access"
          end
        end
    end
  end
end


after "deploy:published", "super_admin:sync_access"
