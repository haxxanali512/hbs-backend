class RolePolicy < ApplicationPolicy
  def index?
    user.super_admin? || accessible?('index', 'users_management_module', 'roles')
  end

  def show?
    user.super_admin? || accessible?('show', 'users_management_module', 'roles')
  end

  def create?
    user.super_admin? || accessible?('create', 'users_management_module', 'roles')
  end

  def update?
    user.super_admin? || accessible?('update', 'users_management_module', 'roles')
  end

  def destroy?
    user.super_admin? || accessible?('destroy', 'users_management_module', 'roles')
  end

  def permissions?
    user.super_admin? || accessible?('update', 'users_management_module', 'roles')
  end

  def duplicate?
    user.super_admin? || accessible?('create', 'users_management_module', 'roles')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      else
        # Regular users can only see their own role
        scope.where(id: user.role_id)
      end
    end
  end
end
