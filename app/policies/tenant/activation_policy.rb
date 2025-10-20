module Tenant
  class ActivationPolicy < ApplicationPolicy
    def index?
      accessible?("tenant", "activation", "index")
    end

    def billing_setup?
      accessible?("tenant", "activation", "create")
    end

    def compliance_setup?
      accessible?("tenant", "activation", "create")
    end

    def document_signing?
      accessible?("tenant", "activation", "create")
    end

    def complete?
      accessible?("tenant", "activation", "complete")
    end

    def activate?
      accessible?("tenant", "activation", "create")
    end

    def update_billing?
      accessible?("tenant", "activation", "update")
    end

    def update_compliance?
      accessible?("tenant", "activation", "update")
    end

    def complete_document_signing?
      accessible?("tenant", "activation", "create")
    end

    def activation_complete?
      accessible?("tenant", "activation", "show")
    end

    def save_stripe_card?
      accessible?("tenant", "activation", "create")
    end

    def manual_payment?
      accessible?("tenant", "activation", "create")
    end

    def stripe_card?
      accessible?("tenant", "activation", "create")
    end

    def send_agreement?
      accessible?("tenant", "activation", "create")
    end

    def check_docusign_status?
      accessible?("tenant", "activation", "show")
    end
  end
end
