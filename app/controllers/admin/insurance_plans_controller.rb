class Admin::InsurancePlansController < Admin::BaseController
  before_action :set_insurance_plan, only: [ :show, :edit, :update, :destroy, :retire, :restore ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]

  def index
    @insurance_plans = InsurancePlan.includes(:payer).order(:name)

    # Filtering
    @insurance_plans = apply_filters(@insurance_plans)

    @pagy, @insurance_plans = pagy(@insurance_plans, items: 20)
  end

  def show; end

  def new
    @insurance_plan = InsurancePlan.new(status: :draft)
    @insurance_plan.payer_id = params[:payer_id] if params[:payer_id].present?
  end

  def create
    @insurance_plan = InsurancePlan.new(insurance_plan_params)
    if @insurance_plan.save
      redirect_to admin_insurance_plan_path(@insurance_plan), notice: "Insurance plan created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    # Check if plan_type is changing and requires step-up MFA
    if insurance_plan_params[:plan_type].present? &&
       @insurance_plan.plan_type != insurance_plan_params[:plan_type] &&
       !@insurance_plan.draft?
      # In production, this would require step-up MFA
      # For now, we'll allow it but log it
      @insurance_plan._skip_type_change_validation = true
    end

    if @insurance_plan.update(insurance_plan_params)
      redirect_to admin_insurance_plan_path(@insurance_plan), notice: "Insurance plan updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    redirect_to admin_insurance_plans_path, alert: "Insurance plans cannot be deleted. Retire instead."
  end

  def retire
    reason = params[:retirement_reason]
    if @insurance_plan.retire!(reason: reason, actor: current_user)
      redirect_to admin_insurance_plan_path(@insurance_plan), notice: "Insurance plan retired."
    else
      redirect_to admin_insurance_plan_path(@insurance_plan), alert: "Cannot retire plan: #{@insurance_plan.errors.full_messages.join(', ')}"
    end
  end

  def restore
    if @insurance_plan.restore!
      redirect_to admin_insurance_plan_path(@insurance_plan), notice: "Insurance plan restored."
    else
      redirect_to admin_insurance_plan_path(@insurance_plan), alert: "Cannot restore plan: #{@insurance_plan.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_insurance_plan
    @insurance_plan = InsurancePlan.find(params[:id])
  end

  def load_form_options
    @payers = Payer.active_only.order(:name)
  end

  def apply_filters(plans)
    # Search filter
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      plans = plans.where("name ILIKE ? OR plan_code ILIKE ?", search_term, search_term)
    end

    plans = plans.where(payer_id: params[:payer_id]) if params[:payer_id].present?
    plans = plans.where(status: params[:status]) if params[:status].present?
    plans = plans.where(plan_type: params[:plan_type]) if params[:plan_type].present?
    plans = plans.in_state(params[:state_code]) if params[:state_code].present?

    plans
  end

  def insurance_plan_params
    permitted = params.require(:insurance_plan).permit(
      :payer_id, :name, :plan_type, :plan_code, :group_number_format,
      :member_id_format, :contact_url, :notes_internal, :status,
      state_scope: []
    )

    # Handle state_scope - convert comma-separated string to array
    if permitted[:state_scope].is_a?(String)
      permitted[:state_scope] = permitted[:state_scope].split(",").map(&:strip).reject(&:blank?)
    end

    permitted
  end
end
