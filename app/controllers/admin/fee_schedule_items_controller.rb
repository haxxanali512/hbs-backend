class Admin::FeeScheduleItemsController < Admin::BaseController
  before_action :set_fee_schedule
  before_action :set_fee_schedule_item, only: [ :show, :edit, :update, :destroy, :activate, :deactivate, :lock, :unlock ]

  def index
    @fee_schedule_items = @fee_schedule.organization_fee_schedule_items
                                      .includes(:procedure_code)
                                      .order(:procedure_code_id)

    # Apply filters
    @fee_schedule_items = @fee_schedule_items.where(active: params[:active] == "true") if params[:active].present?
    @fee_schedule_items = @fee_schedule_items.where(locked: params[:locked] == "true") if params[:locked].present?
    @fee_schedule_items = @fee_schedule_items.joins(:procedure_code)
                                            .where("procedure_codes.code ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    @pagy, @fee_schedule_items = pagy(@fee_schedule_items, items: 20)
    @procedure_codes = ProcedureCode.order(:code)
  end

  def show
  end

  def new
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.build
    @procedure_codes = ProcedureCode.order(:code)
  end

  def create
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.build(fee_schedule_item_params)

    if @fee_schedule_item.save
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item created successfully."
    else
      @procedure_codes = ProcedureCode.order(:code)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @procedure_codes = ProcedureCode.order(:code)
  end

  def update
    if @fee_schedule_item.update(fee_schedule_item_params)
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item updated successfully."
    else
      @procedure_codes = ProcedureCode.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @fee_schedule_item.can_be_deleted?
      @fee_schedule_item.discard
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item deleted successfully."
    else
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "FEE_ITEM_IN_USE - Item has posted claims; deactivate instead."
    end
  end

  def activate
    if @fee_schedule_item.update(active: true)
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item activated successfully."
    else
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to activate fee schedule item."
    end
  end

  def deactivate
    if @fee_schedule_item.update(active: false)
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item deactivated successfully."
    else
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to deactivate fee schedule item."
    end
  end

  def lock
    if @fee_schedule_item.update(locked: true)
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item locked successfully."
    else
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to lock fee schedule item."
    end
  end

  def unlock
    if @fee_schedule_item.update(locked: false)
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item unlocked successfully."
    else
      redirect_to admin_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to unlock fee schedule item."
    end
  end

  private

  def set_fee_schedule
    @fee_schedule = OrganizationFeeSchedule.kept.find(params[:fee_schedule_id])
  end

  def set_fee_schedule_item
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.find(params[:id])
  end

  def fee_schedule_item_params
    params.require(:organization_fee_schedule_item).permit(
      :procedure_code_id, :unit_price, :pricing_rule, :active, :locked
    )
  end
end
