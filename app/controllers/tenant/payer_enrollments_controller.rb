class Tenant::PayerEnrollmentsController < Tenant::BaseController
  before_action :set_current_organization

  def index
    @payer_enrollments = @current_organization.payer_enrollments
      .includes(:payer, :provider, :organization_location)
      .order(created_at: :desc)

    @payer_enrollments = @payer_enrollments.where(payer_id: params[:payer_id]) if params[:payer_id].present?

    @payer_enrollments = @payer_enrollments.where(status: params[:status]) if params[:status].present?

    @payer_enrollments = @payer_enrollments.where(enrollment_type: params[:enrollment_type]) if params[:enrollment_type].present?

    @pagy, @payer_enrollments = pagy(@payer_enrollments, items: 20)
  end

  private

  def set_current_organization
    @current_organization = current_user.organization
  end
end
