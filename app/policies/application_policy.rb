# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user[:user]
    @record = record
  end

  private

  def accessible?(action, main_module, sub_module)
    permissions = user.permissions_for(action, main_module, sub_module)
    permissions.present? && permissions == true
  end

  class Scope
    def initialize(user, scope)
      @user = user[:user]
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
