class Admin::DashboardController < Admin::BaseController
  include ActivationStepsConcern

  def index
    @organizations_count = Organization.count
    @active_organizations = Organization.where(activation_status: :activated).count
    @total_users = User.count
    @pending_billings = OrganizationBilling.pending_approval.count
    @recent_organizations = Organization.includes(:owner).order(created_at: :desc).limit(10)
    @recent_users = User.order(created_at: :desc).limit(5)

    # Load all activated organizations with their onboarding status
    @activated_organizations = Organization.where(activation_status: :activated)
                                         .includes(:owner, :activation_checklist, org_accepted_plans: [:organization_activation_plan_steps, :insurance_plan])
                                         .order(:name)
    
    # Pre-calculate onboarding statuses for each organization
    @organizations_onboarding_status = {}
    @activated_organizations.each do |org|
      @organizations_onboarding_status[org.id] = build_detailed_activation_steps(org)
    end

    # Calculate growth metrics
    @organizations_growth = calculate_growth(Organization, 30.days.ago)
    @users_growth = calculate_growth(User, 30.days.ago)
  end

  private

  def calculate_growth(model, since)
    total = model.count
    recent = model.where("created_at > ?", since).count
    return 0 if total == 0

    ((recent.to_f / total) * 100).round(1)
  end
end
