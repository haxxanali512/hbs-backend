class AdminAccessService
  class << self
    def sync_super_admin_access
      role = Role.find_by(role_name: "Super Admin")
      return unless role

      role.update!(access: HbsCustoms::ModulePermission.admin_access)
    end
  end
end
