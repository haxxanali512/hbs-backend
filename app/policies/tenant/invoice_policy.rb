class Tenant::InvoicePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "invoices", "index")
  end

  def show?
    accessible?("tenant", "invoices", "show")
  end

  # def create?
  #   accessible?("tenant", "invoices", "create")
  # end

  # def update?
  #   accessible?("tenant", "invoices", "update")
  # end

  # def destroy?
  #   accessible?("tenant", "invoices", "destroy")
  # end

  # def send_invoice?
  #   accessible?("tenant", "invoices", "send")
  # end

  # def void?
  #   accessible?("tenant", "invoices", "void")
  # end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
