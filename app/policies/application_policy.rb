# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record, :organization, :membership

  def initialize(context, record)
    @user = context.is_a?(Hash) ? context[:user] : context
    @organization = context[:organization] if context.is_a?(Hash)
    @membership = context[:membership] if context.is_a?(Hash)
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  def accessible?(action, main_module, sub_module)
    return true if user&.super_admin?

    # Check global role permissions
    global_permissions = user&.permissions_for(action, main_module, sub_module)
    return true if global_permissions == true || global_permissions == "true"

    # Check tenant role permissions if in organization context
    if organization && membership&.organization_role
      tenant_permissions = membership.organization_role.access.dig(main_module, sub_module, action)
      return true if tenant_permissions == true || tenant_permissions == "true"
    end

    false
  end

  def current_org_member?
    return true if user&.super_admin?
    return false unless organization
    user&.member_of?(organization)
  end

  def organization_admin?
    return true if user&.super_admin?
    return false unless organization
    user&.organization_admin?(organization)
  end

  class Scope
    def initialize(context, scope)
      @user = context.is_a?(Hash) ? context[:user] : context
      @organization = context[:organization] if context.is_a?(Hash)
      @membership = context[:membership] if context.is_a?(Hash)
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope, :organization, :membership
  end
end

# def index?
#   accessible?('index', 'labs_module', 'sample_reception')
# end
