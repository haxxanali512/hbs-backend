class Tenant::OrgAcceptedPlansController < Tenant::BaseController
  before_action :set_org_accepted_plan, only: [ :show, :edit, :update, :activate, :inactivate ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]


  def index
    @org_accepted_plans = @current_organization.org_accepted_plans
      .includes(:insurance_plan, :added_by)
      .order(created_at: :desc)

    # Set filter options for shared filters partial
    @insurance_plan_options = InsurancePlan.active_only.order(:name)
    @network_type_options = OrgAcceptedPlan.network_types.keys
    @enrollment_status_options = OrgAcceptedPlan.enrollment_statuses.keys
    @status_options = OrgAcceptedPlan.statuses.keys

    # Filtering
    @org_accepted_plans = apply_filters(@org_accepted_plans)

    @pagy, @org_accepted_plans = pagy(@org_accepted_plans, items: 20)
  end

  def show; end

  def new
    @org_accepted_plan = @current_organization.org_accepted_plans.build(
      status: :draft,
      network_type: :out_of_network,
      enrollment_status: :pending,
      effective_date: Date.current
    )
    @org_accepted_plan.insurance_plan_id = params[:insurance_plan_id] if params[:insurance_plan_id].present?
  end

  def create
    @org_accepted_plan = @current_organization.org_accepted_plans.build(org_accepted_plan_params)
    @org_accepted_plan.organization_id = @current_organization.id
    @org_accepted_plan.added_by_id = current_user.id
    if @org_accepted_plan.save
      redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), notice: "Organization accepted plan created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    authorize @org_accepted_plan
    # Client admins can only update certain fields
    unless current_user.has_admin_access?
      permitted_params = org_accepted_plan_params.slice(:status, :network_type, :effective_date, :end_date, :notes)
      if @org_accepted_plan.update(permitted_params)
        redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), notice: "Organization accepted plan updated."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @org_accepted_plan.update(org_accepted_plan_params)
        redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), notice: "Organization accepted plan updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def activate
    authorize @org_accepted_plan
    if @org_accepted_plan.activate!
      redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), notice: "Plan activated."
    else
      redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), alert: "Cannot activate plan: #{@org_accepted_plan.errors.full_messages.join(', ')}"
    end
  end

  def inactivate
    authorize @org_accepted_plan
    if @org_accepted_plan.inactivate!
      redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), notice: "Plan inactivated."
    else
      redirect_to tenant_org_accepted_plan_path(@org_accepted_plan), alert: "Cannot inactivate plan: #{@org_accepted_plan.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_org_accepted_plan
    @org_accepted_plan = @current_organization.org_accepted_plans.find(params[:id])
  end

  def load_form_options
    @insurance_plans = InsurancePlan.active_only.order(:name)
  end

  def apply_filters(plans)
    plans = plans.where(insurance_plan_id: params[:insurance_plan_id]) if params[:insurance_plan_id].present?
    plans = plans.where(status: params[:status]) if params[:status].present?
    plans = plans.where(network_type: params[:network_type]) if params[:network_type].present?
    plans = plans.where(enrollment_status: params[:enrollment_status]) if params[:enrollment_status].present?

    plans
  end

  def org_accepted_plan_params
    params.require(:org_accepted_plan).permit(
      :insurance_plan_id, :status, :network_type,
      :enrollment_status, :effective_date, :end_date, :notes
    )
  end
end
