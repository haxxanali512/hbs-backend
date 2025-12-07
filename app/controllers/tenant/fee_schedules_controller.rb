class Tenant::FeeSchedulesController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_fee_schedule, only: [ :show, :edit, :update, :destroy, :lock, :unlock ]

  def index
    # Get or create the organization's fee schedule
    @fee_schedule = @current_organization.get_or_create_fee_schedule

    # Get all fee schedule items for the organization
    @fee_schedule_items = @fee_schedule.organization_fee_schedule_items
                                      .includes(:procedure_code)
                                      .order(:procedure_code_id)

    # Apply filters
    @fee_schedule_items = @fee_schedule_items.where(active: params[:active] == "true") if params[:active].present?
    @fee_schedule_items = @fee_schedule_items.joins(:procedure_code)
                                            .where("procedure_codes.code ILIKE ? OR procedure_codes.description ILIKE ?",
                                                   "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    # If showing active items, ensure only one per procedure code (enforce uniqueness)
    if params[:active] == "true" || params[:active].blank?
      # Group by procedure_code_id and take only the first active item per code
      active_items = @fee_schedule_items.where(active: true)
      procedure_code_ids = active_items.pluck(:procedure_code_id).uniq
      @fee_schedule_items = @fee_schedule_items.where(
        id: active_items.where(procedure_code_id: procedure_code_ids)
                       .group(:procedure_code_id)
                       .select("MIN(organization_fee_schedule_items.id)")
      ).or(@fee_schedule_items.where(active: false))
    end

    @pagy, @fee_schedule_items = pagy(@fee_schedule_items, items: 20)
  end

  def show
    @items = @fee_schedule.organization_fee_schedule_items
                         .includes(:procedure_code)
                         .order(:procedure_code_id)
    @pricing_summary = FeeSchedulePricingService.get_organization_pricing_summary(@current_organization.id)
  end

  def new
    @fee_schedule = @current_organization.organization_fee_schedules.build
    @specialties = Specialty.active.order(:name)
  end

  def create
    @fee_schedule = @current_organization.organization_fee_schedules.build(fee_schedule_params)

    if @fee_schedule.save
      redirect_to tenant_fee_schedule_path(@fee_schedule), notice: "Fee schedule created successfully."
    else
      @specialties = Specialty.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @specialties = Specialty.active.order(:name)
  end

  def update
    if @fee_schedule.update(fee_schedule_params)
      redirect_to tenant_fee_schedule_path(@fee_schedule), notice: "Fee schedule updated successfully."
    else
      @specialties = Specialty.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @fee_schedule.discard
      redirect_to tenant_fee_schedules_path, notice: "Fee schedule deleted successfully."
    else
      redirect_to tenant_fee_schedule_path(@fee_schedule), alert: "Failed to delete fee schedule."
    end
  end

  def lock
    if @fee_schedule.update(locked: true)
      redirect_to tenant_fee_schedule_path(@fee_schedule), notice: "Fee schedule locked successfully."
    else
      redirect_to tenant_fee_schedule_path(@fee_schedule), alert: "Failed to lock fee schedule."
    end
  end

  def unlock
    if @fee_schedule.update(locked: false)
      redirect_to tenant_fee_schedule_path(@fee_schedule), notice: "Fee schedule unlocked successfully."
    else
      redirect_to tenant_fee_schedule_path(@fee_schedule), alert: "Failed to unlock fee schedule."
    end
  end

  private

  def set_fee_schedule
    @fee_schedule = @current_organization.organization_fee_schedules.kept.find(params[:id])
  end

  def fee_schedule_params
    params.require(:organization_fee_schedule).permit(
      :specialty_id, :name, :currency, :notes, :locked
    )
  end
end
