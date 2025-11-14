class Tenant::SupportTicketCommentPolicy < ApplicationPolicy
  def create?
    accessible?("tenant", "support_ticket_comments", "create")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
