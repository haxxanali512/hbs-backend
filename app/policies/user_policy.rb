class UserPolicy < ApplicationPolicy
  def index?
    user.super_admin? || accessible?('index', 'users_management_module', 'users')
  end

  def show?
    user.super_admin? || (record == user) || accessible?('show', 'users_management_module', 'users')
  end

  def create?
    user.super_admin? || accessible?('create', 'users_management_module', 'users')
  end

  def update?
    user.super_admin? || (record == user) || accessible?('update', 'users_management_module', 'users')
  end

  def destroy?
    user.super_admin? || accessible?('destroy', 'users_management_module', 'users')
  end

  def invite?
    user.super_admin? || accessible?('create', 'users_management_module', 'invitations')
  end

  def reinvite?
    user.super_admin? || accessible?('update', 'users_management_module', 'invitations')
  end

  def reset_password?
    user.super_admin? || accessible?('update', 'users_management_module', 'users')
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.super_admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
