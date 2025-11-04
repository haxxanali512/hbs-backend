class Admin::DenialPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "denials", "index")
  end

  def show?
    accessible?("admin", "denials", "show")
  end

  def create?
    accessible?("admin", "denials", "create")
  end

  def update?
    accessible?("admin", "denials", "update")
  end

  def update_status?
    accessible?("admin", "denials", "update_status")
  end

  def resubmit?
    accessible?("admin", "denials", "resubmit")
  end

  def mark_non_correctable?
    accessible?("admin", "denials", "mark_non_correctable")
  end

  def override_attempt_limit?
    accessible?("admin", "denials", "override_attempt_limit")
  end

  def attach_doc?
    accessible?("admin", "denials", "attach_doc")
  end

  def remove_doc?
    accessible?("admin", "denials", "remove_doc")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
