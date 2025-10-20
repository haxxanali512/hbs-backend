module Admin
  class InvoicePolicy < ApplicationPolicy
    def index?
      accessible?("admin", "invoices", "index")
    end

    def show?
      accessible?("admin", "invoices", "show")
    end

    def new?
      accessible?("admin", "invoices", "create")
    end

    def create?
      accessible?("admin", "invoices", "create")
    end

    def edit?
      accessible?("admin", "invoices", "edit")
    end

    def update?
      accessible?("admin", "invoices", "update")
    end

    def issue?
      accessible?("admin", "invoices", "create")
    end

    def void?
      accessible?("admin", "invoices", "destroy")
    end

    def apply_payment?
      accessible?("admin", "invoices", "create")
    end

    def pay?
      accessible?("admin", "invoices", "create")
    end

    def download_pdf?
      accessible?("admin", "invoices", "show")
    end
  end
end
