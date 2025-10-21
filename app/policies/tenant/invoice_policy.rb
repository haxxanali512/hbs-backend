class Tenant::InvoicePolicy < ApplicationPolicy
  def index?
    accessible?("tenant", "invoices", "index")
  end

  def show?
    accessible?("tenant", "invoices", "show")
  end

  def download_pdf?
    accessible?("tenant", "invoices", "show")
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
