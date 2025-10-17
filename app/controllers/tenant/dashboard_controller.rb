class Tenant::DashboardController < Tenant::BaseController
  # before_action :check_activation_status, only: [ :activation, :billing_setup, :update_billing, :manual_payment, :compliance_setup, :update_compliance, :document_signing, :complete_document_signing, :activation_complete, :activate ]

  def index
    if @current_organization.activated?
      # Show full dashboard with sidebar
      @organizations_count = Organization.count
      @active_organizations = Organization.where(activation_status: :activated).count
      @total_users = User.count
      @pending_billings = OrganizationBilling.pending_approval.count
      @recent_organizations = Organization.order(created_at: :desc).limit(5)
      @recent_users = User.order(created_at: :desc).limit(5)

      # Calculate growth metrics
      @organizations_growth = calculate_growth(Organization, 30.days.ago)
      @users_growth = calculate_growth(User, 30.days.ago)

      # Rails will automatically render index.html.erb
    else
      # Redirect non-activated organizations to activation overview
      redirect_to tenant_activation_path
    end
  end

  # Activation methods (moved from Tenant::ActivationController)

  private

  def calculate_growth(model, since)
    total = model.count
    recent = model.where("created_at > ?", since).count
    return 0 if total == 0

    ((recent.to_f / total) * 100).round(1)
  end
end
