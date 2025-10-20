class Admin::DashboardController < Admin::BaseController
  def index
    @organizations_count = Organization.count
    @active_organizations = Organization.where(activation_status: :activated).count
    @total_users = User.count
    @pending_billings = OrganizationBilling.pending_approval.count
    @recent_organizations = Organization.order(created_at: :desc).limit(5)
    @recent_users = User.order(created_at: :desc).limit(5)

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
