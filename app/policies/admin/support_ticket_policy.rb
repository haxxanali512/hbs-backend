class Admin::SupportTicketPolicy < ApplicationPolicy
  def index?
    accessible?("admin", "support_tickets", "index")
  end

  def show?
    accessible?("admin", "support_tickets", "show")
  end

  def update?
    accessible?("admin", "support_tickets", "update")
  end

  def close?
    accessible?("admin", "support_tickets", "close")
  end

  def reopen?
    accessible?("admin", "support_tickets", "reopen")
  end

  def add_internal_note?
    accessible?("admin", "support_tickets", "add_internal_note")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
