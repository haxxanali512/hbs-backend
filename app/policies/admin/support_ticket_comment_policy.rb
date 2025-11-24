class Admin::SupportTicketCommentPolicy < ApplicationPolicy
  def create?
    accessible?("admin", "support_ticket_comments", "create")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
