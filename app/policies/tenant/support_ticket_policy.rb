class Tenant::SupportTicketPolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "support_tickets", "index")
  end

  def show?
    accessible?("tenant", "support_tickets", "show")
  end

  def new?
    create?
  end

  def create?
    accessible?("tenant", "support_tickets", "create")
  end

  def linked_resources?
    accessible?("tenant", "support_tickets", "index")
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
