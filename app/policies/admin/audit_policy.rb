class Admin::AuditPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "audits", "index")
  end

  def show?
    accessible?("admin", "audits", "show")
  end

  def model_audits?
    accessible?("admin", "audits", "model_audits")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
