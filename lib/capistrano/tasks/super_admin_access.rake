namespace :super_admin do
  desc "Sync Super Admin role access to ModulePermission.admin_access"
  task :sync_access do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env, fetch(:stage)) do
          script = %q[
            role = Role.find_by(role_name: "Super Admin");
            if role
              role.update!(access: HbsCustoms::ModulePermission.admin_access);
              puts "Super Admin access synced successfully";
            else
              puts "Super Admin role not found";
            end
          ].squish
          execute :bundle, :exec, :rails, "runner", script
        end
      end
    end
  end
end


after "deploy:published", "super_admin:sync_access"
