class Tenant::EncounterCommentPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "encounter_comments", "index")
  end

  def create?
    accessible?("tenant", "encounter_comments", "create")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
