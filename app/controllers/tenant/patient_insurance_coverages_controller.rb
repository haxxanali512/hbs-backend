class Tenant::PatientInsuranceCoveragesController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_patient_insurance_coverage, only: [ :show, :edit, :update, :destroy, :activate, :terminate ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]

  def index
    @patient_insurance_coverages = @current_organization.patient_insurance_coverages
      .includes(:patient, :insurance_plan)
      .order(created_at: :desc)

    # Set filter options for shared filters partial
    @patient_options = @current_organization.patients.order(:last_name, :first_name)
    @insurance_plan_options = @current_organization.eligible_insurance_plans_for_patient_coverages
    @coverage_order_options = PatientInsuranceCoverage.coverage_orders.keys
    @status_options = PatientInsuranceCoverage.statuses.keys

    # Filtering
    @patient_insurance_coverages = apply_filters(@patient_insurance_coverages)

    @pagy, @patient_insurance_coverages = pagy(@patient_insurance_coverages, items: 20)
  end

  def show; end

  def new
    @patient_insurance_coverage = @current_organization.patient_insurance_coverages.build(
      status: :draft,
      coverage_order: :primary
    )
    @patient_insurance_coverage.patient_id = params[:patient_id] if params[:patient_id].present?
    @patient_insurance_coverage.insurance_plan_id = params[:insurance_plan_id] if params[:insurance_plan_id].present?
  end

  def create
    @patient_insurance_coverage = @current_organization.patient_insurance_coverages.build(patient_insurance_coverage_params)
    @patient_insurance_coverage.organization_id = @current_organization.id

    if @patient_insurance_coverage.save
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), notice: "Patient insurance coverage created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    # Check if coverage is referenced and user is not HBS
    unless current_user.has_admin_access?
      unless @patient_insurance_coverage.can_be_deleted?
        redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), alert: "Coverage is referenced and cannot be edited. Please contact HBS."
        return
      end
    end

    if @patient_insurance_coverage.update(patient_insurance_coverage_params)
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), notice: "Patient insurance coverage updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @patient_insurance_coverage.can_be_deleted?
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), alert: "Cannot delete coverage that is referenced by encounters/claims. Terminate or replace instead."
      return
    end

    @patient_insurance_coverage.destroy
    redirect_to tenant_patient_insurance_coverages_path, notice: "Coverage deleted."
  end

  def activate
    if @patient_insurance_coverage.activate!
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), notice: "Coverage activated."
    else
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), alert: "Cannot activate coverage: #{@patient_insurance_coverage.errors.full_messages.join(', ')}"
    end
  end

  def terminate
    # Accept termination_date from either direct param or nested form param
    termination_date = params[:termination_date].presence || params.dig(:patient_insurance_coverage, :termination_date).presence

    # Parse the date string if it's a string
    if termination_date.is_a?(String)
      termination_date = Date.parse(termination_date) rescue Date.current
    end

    termination_date ||= Date.current

    if @patient_insurance_coverage.terminate!(termination_date: termination_date, actor: current_user)
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), notice: "Coverage terminated with termination date: #{termination_date.strftime('%m/%d/%Y')}."
    else
      redirect_to tenant_patient_insurance_coverage_path(@patient_insurance_coverage), alert: "Cannot terminate coverage: #{@patient_insurance_coverage.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_patient_insurance_coverage
    @patient_insurance_coverage = @current_organization.patient_insurance_coverages.find(params[:id])
  end

  def load_form_options
    @patients = @current_organization.patients.active.order(:last_name, :first_name)
    @insurance_plans = @current_organization.eligible_insurance_plans_for_patient_coverages
  end

  def apply_filters(coverages)
    coverages = coverages.where(patient_id: params[:patient_id]) if params[:patient_id].present?
    coverages = coverages.where(insurance_plan_id: params[:insurance_plan_id]) if params[:insurance_plan_id].present?
    coverages = coverages.where(status: params[:status]) if params[:status].present?
    coverages = coverages.where(coverage_order: params[:coverage_order]) if params[:coverage_order].present?

    coverages
  end

  def patient_insurance_coverage_params
    permitted = params.require(:patient_insurance_coverage).permit(
      :patient_id, :insurance_plan_id, :member_id,
      :subscriber_name, :relationship_to_subscriber, :coverage_order,
      :effective_date, :termination_date, :status,
      subscriber_address: {}
    )

    # Handle subscriber_address if it comes as separate fields
    if params[:patient_insurance_coverage][:subscriber_address_line1].present?
      permitted[:subscriber_address] = {
        line1: params[:patient_insurance_coverage][:subscriber_address_line1],
        line2: params[:patient_insurance_coverage][:subscriber_address_line2],
        city: params[:patient_insurance_coverage][:subscriber_address_city],
        state: params[:patient_insurance_coverage][:subscriber_address_state],
        postal: params[:patient_insurance_coverage][:subscriber_address_postal],
        country: params[:patient_insurance_coverage][:subscriber_address_country] || "US"
      }
    end

    permitted
  end
end
