class Admin::PayerEnrollmentsController < Admin::BaseController
  before_action :set_payer_enrollment, only: [ :show, :edit, :update, :destroy, :submit, :approve, :cancel, :resubmit ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]

  def index
    load_form_options

    @payer_enrollments = PayerEnrollment.includes(:organization, :payer, :provider, :organization_location)
      .order(created_at: :desc)

    @payer_enrollments = apply_filters(@payer_enrollments)

    @pagy, @payer_enrollments = pagy(@payer_enrollments, items: 20)
  end

  def show; end

  def new
    @payer_enrollment = PayerEnrollment.new(status: :draft)
    @payer_enrollment.organization_id = params[:organization_id] if params[:organization_id].present?
  end

  def create
    @payer_enrollment = PayerEnrollment.new(payer_enrollment_params)
    if @payer_enrollment.save
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Payer enrollment created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @payer_enrollment.update(payer_enrollment_params)
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Payer enrollment updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_to admin_payer_enrollments_path, alert: "Enrollments cannot be deleted. Cancel instead."
  end

  def submit
    begin
      @payer_enrollment.submit!
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Enrollment submitted successfully."
    rescue => _e
      redirect_to admin_payer_enrollment_path(@payer_enrollment), alert: "Cannot submit enrollment: #{@payer_enrollment.errors.full_messages.join(', ')}"
    end
  end

  def approve
    unless @payer_enrollment.active? && !@payer_enrollment.approved?
      redirect_to admin_payer_enrollment_path(@payer_enrollment), alert: "Enrollment cannot be approved in its current status."
      return
    end
    begin
      @payer_enrollment.approve!(bypass_clearinghouse: true)
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Enrollment approved."
    rescue => e
      redirect_to admin_payer_enrollment_path(@payer_enrollment), alert: "Could not approve enrollment: #{@payer_enrollment.errors.full_messages.join(', ')}"
    end
  end

  def cancel
    reason = params[:cancellation_reason] || "Cancelled by admin"
    begin
      @payer_enrollment.cancel!(reason: reason, cancelled_by: current_user)
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Enrollment cancelled."
    rescue => _e
      redirect_to admin_payer_enrollment_path(@payer_enrollment), alert: "Cannot cancel enrollment: #{@payer_enrollment.errors.full_messages.join(', ')}"
    end
  end

  def resubmit
    begin
      @payer_enrollment.resubmit!
      redirect_to admin_payer_enrollment_path(@payer_enrollment), notice: "Enrollment resubmitted successfully."
    rescue => _e
      redirect_to admin_payer_enrollment_path(@payer_enrollment), alert: "Cannot resubmit enrollment: #{@payer_enrollment.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_payer_enrollment
    @payer_enrollment = PayerEnrollment.find(params[:id])
  end

  def load_form_options
    @organizations = Organization.where(activation_status: :activated).order(:name)
    @payers = Payer.active_only.order(:name)
    org_id = @payer_enrollment&.organization_id || params.dig(:payer_enrollment, :organization_id) || params[:organization_id]
    @providers = if org_id.present?
      Organization.find(org_id).providers.kept.active.order(:last_name, :first_name)
    else
      Provider.kept.active.order(:last_name, :first_name)
    end
    @locations = if org_id.present?
      OrganizationLocation.kept.active.by_organization(org_id).order(:name)
    else
      OrganizationLocation.kept.active.order(:name)
    end

    # Shared filters configuration for admin index views
    @organization_options = @organizations
    @payer_options = @payers.map { |p| [p.name, p.id] }
    @status_options = PayerEnrollment.statuses.keys
    @use_status_for_action_type = true
    @custom_selects = [
      {
        param: :enrollment_type,
        label: "Type",
        options: [["All Types", ""]] + PayerEnrollment.enrollment_types.keys.map { |k| [k.humanize, k] }
      }
    ]
  end

  def apply_filters(enrollments)
    enrollments = enrollments.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    enrollments = enrollments.where(payer_id: params[:payer_id]) if params[:payer_id].present?
    enrollments = enrollments.where(status: params[:status]) if params[:status].present?
    enrollments = enrollments.where(enrollment_type: params[:enrollment_type]) if params[:enrollment_type].present?
    enrollments = enrollments.where(provider_id: params[:provider_id]) if params[:provider_id].present?
    enrollments = enrollments.where(organization_location_id: params[:organization_location_id]) if params[:organization_location_id].present?

    enrollments
  end

  def payer_enrollment_params
    params.require(:payer_enrollment).permit(
      :organization_id, :payer_id, :enrollment_type, :status,
      :provider_id, :organization_location_id, :external_enrollment_id,
      :submitted_at, :approved_at, :rejected_at, :cancelled_at, :cancellation_reason
    )
  end
end
