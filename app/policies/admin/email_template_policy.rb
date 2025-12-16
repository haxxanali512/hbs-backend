class Admin::EmailTemplatePolicy < ApplicationPolicy
  def index?
    accessible?("admin", "email_templates", "index")
  end

  def show?
    accessible?("admin", "email_templates", "show")
  end

  def create?
    accessible?("admin", "email_templates", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "email_templates", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "email_templates", "destroy")
  end

  def retire?
    accessible?("admin", "email_templates", "retire")
  end

  def activate?
    accessible?("admin", "email_templates", "activate")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
