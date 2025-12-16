class Admin::FeeSchedulesController < Admin::BaseController
  before_action :set_fee_schedule, only: [ :show, :edit, :update, :destroy, :lock, :unlock ]

  def index
    @fee_schedules = OrganizationFeeSchedule.kept
                                           .includes(:organization, :specialties, :organization_fee_schedule_items)
                                           .order(:organization_id)

    # Apply filters
    @fee_schedules = @fee_schedules.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    @fee_schedules = @fee_schedules.where(locked: params[:locked] == "true") if params[:locked].present?
    @fee_schedules = @fee_schedules.where(currency: params[:currency]) if params[:currency].present?

    @pagy, @fee_schedules = pagy(@fee_schedules, items: 20)
    @organizations = Organization.kept.order(:name)
  end

  def show
    @items = @fee_schedule.organization_fee_schedule_items
                         .includes(:procedure_code)
                         .order(:procedure_code_id)
    @pricing_summary = FeeSchedulePricingService.get_organization_pricing_summary(@fee_schedule.organization_id)
  end

  def new
    @fee_schedule = OrganizationFeeSchedule.new
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.active.order(:name)
  end

  def create
    @fee_schedule = OrganizationFeeSchedule.new(fee_schedule_params)

    if @fee_schedule.save
      redirect_to admin_fee_schedule_path(@fee_schedule), notice: "Fee schedule created successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.active.order(:name)
  end

  def update
    if @fee_schedule.update(fee_schedule_params)
      redirect_to admin_fee_schedule_path(@fee_schedule), notice: "Fee schedule updated successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @fee_schedule.discard
      redirect_to admin_fee_schedules_path, notice: "Fee schedule deleted successfully."
    else
      redirect_to admin_fee_schedule_path(@fee_schedule), alert: "Failed to delete fee schedule."
    end
  end

  def lock
    if @fee_schedule.update(locked: true)
      redirect_to admin_fee_schedule_path(@fee_schedule), notice: "Fee schedule locked successfully."
    else
      redirect_to admin_fee_schedule_path(@fee_schedule), alert: "Failed to lock fee schedule."
    end
  end

  def unlock
    if @fee_schedule.update(locked: false)
      redirect_to admin_fee_schedule_path(@fee_schedule), notice: "Fee schedule unlocked successfully."
    else
      redirect_to admin_fee_schedule_path(@fee_schedule), alert: "Failed to unlock fee schedule."
    end
  end

  private

  def set_fee_schedule
    @fee_schedule = OrganizationFeeSchedule.kept.find(params[:id])
  end

  def fee_schedule_params
    params.require(:organization_fee_schedule).permit(
      :organization_id, :name, :currency, :notes, :locked
    )
  end
end
