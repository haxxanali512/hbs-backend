class Tenant::FeeScheduleItemsController < Tenant::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :set_fee_schedule
  before_action :set_fee_schedule_item, only: [ :show, :edit, :update, :destroy, :activate, :deactivate ]

  def index
    @fee_schedule_items = @fee_schedule.organization_fee_schedule_items
                                      .includes(:procedure_code)
                                      .order(:procedure_code_id)

    # Apply filters
    @fee_schedule_items = @fee_schedule_items.where(active: params[:active] == "true") if params[:active].present?
    @fee_schedule_items = @fee_schedule_items.joins(:procedure_code)
                                            .where("procedure_codes.code ILIKE ?", "%#{params[:search]}%") if params[:search].present?

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
    @procedure_codes = ProcedureCode.order(:code)
  end

  def show
  end

  def new
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.build
    @procedure_codes = ProcedureCode.order(:code)
    @existing_items_by_code = {}

    # Pre-check which procedure codes already have active items for this organization
    if params[:procedure_code_id].present?
      procedure_code = ProcedureCode.find_by(id: params[:procedure_code_id])
      if procedure_code
        existing_item = @current_organization.fee_schedule_item_for(procedure_code)
        @existing_items_by_code[procedure_code.id] = existing_item if existing_item
      end
    end
  end

  def create
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.build(fee_schedule_item_params)

    # Pre-check: if trying to create an active item, check if one already exists
    if @fee_schedule_item.active? && @fee_schedule_item.procedure_code_id.present?
      existing_item = @current_organization.fee_schedule_item_for(@fee_schedule_item.procedure_code)
      if existing_item && existing_item.id != @fee_schedule_item.id
        @fee_schedule_item.errors.add(:procedure_code, "FEE_DUP_ITEM - An active fee schedule item already exists for this procedure code in your organization.")
        @procedure_codes = ProcedureCode.order(:code)
        render :new, status: :unprocessable_entity
        return
      end
    end

    if @fee_schedule_item.save
      redirect_to tenant_fee_schedule_fee_schedule_items_path(@fee_schedule),
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
      respond_to do |format|
        format.html do
          redirect_to tenant_fee_schedules_path,
                      notice: "Fee schedule item updated successfully."
        end
        format.json do
          render json: {
            success: true,
            item: {
              id: @fee_schedule_item.id,
              unit_price: @fee_schedule_item.unit_price,
              formatted_price: number_to_currency(@fee_schedule_item.unit_price || 0)
            }
          }
        end
      end
    else
      respond_to do |format|
        format.html do
          @procedure_codes = ProcedureCode.order(:code)
          render :edit, status: :unprocessable_entity
        end
        format.json do
          render json: {
            success: false,
            errors: @fee_schedule_item.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if @fee_schedule_item.can_be_deleted?
      @fee_schedule_item.discard
      redirect_to tenant_fee_schedules_path,
                  notice: "Fee schedule item deleted successfully."
    else
      redirect_to tenant_fee_schedules_path,
                  alert: "FEE_ITEM_IN_USE - Item has posted claims; deactivate instead."
    end
  end

  def activate
    if @fee_schedule_item.update(active: true)
      redirect_to tenant_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item activated successfully."
    else
      redirect_to tenant_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to activate fee schedule item."
    end
  end

  def deactivate
    if @fee_schedule_item.update(active: false)
      redirect_to tenant_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  notice: "Fee schedule item deactivated successfully."
    else
      redirect_to tenant_fee_schedule_fee_schedule_items_path(@fee_schedule),
                  alert: "Failed to deactivate fee schedule item."
    end
  end

  private

  def set_fee_schedule
    @fee_schedule = @current_organization.organization_fee_schedules.kept.find(params[:fee_schedule_id])
  end

  def set_fee_schedule_item
    @fee_schedule_item = @fee_schedule.organization_fee_schedule_items.find(params[:id])
  end

  def fee_schedule_item_params
    params.require(:organization_fee_schedule_item).permit(
      :procedure_code_id, :unit_price, :pricing_rule, :active
    )
  end
end
