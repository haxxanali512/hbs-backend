class Admin::EmailTemplateKeyPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "email_template_keys", "index")
  end

  def show?
    accessible?("admin", "email_template_keys", "show")
  end

  def create?
    accessible?("admin", "email_template_keys", "create")
  end

  def new?
    create?
  end

  def update?
    accessible?("admin", "email_template_keys", "update")
  end

  def edit?
    update?
  end

  def destroy?
    accessible?("admin", "email_template_keys", "destroy")
  end

  def retire?
    accessible?("admin", "email_template_keys", "retire")
  end

  def activate?
    accessible?("admin", "email_template_keys", "activate")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
