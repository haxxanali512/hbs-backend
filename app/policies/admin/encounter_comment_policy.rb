class Admin::EncounterCommentPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "encounter_comments", "index")
  end

  def create?
    accessible?("admin", "encounter_comments", "create")
  end

  def redact?
    accessible?("admin", "encounter_comments", "redact")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
