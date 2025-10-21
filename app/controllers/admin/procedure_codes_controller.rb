class Admin::ProcedureCodesController < Admin::BaseController
  before_action :set_procedure_code, only: [ :show, :edit, :update, :destroy, :toggle_status ]

  def index
    @procedure_codes = ProcedureCode.kept
                                   .includes(:specialties)
                                   .order(:code_type, :code)

    # Apply filters
    @procedure_codes = @procedure_codes.search(params[:search]) if params[:search].present?
    @procedure_codes = @procedure_codes.by_code_type(params[:code_type]) if params[:code_type].present?
    @procedure_codes = @procedure_codes.by_status(params[:status]) if params[:status].present?

    @pagy, @procedure_codes = pagy(@procedure_codes, items: 20)
  end

  def show
    @specialties = @procedure_code.specialties.active.order(:name)
    @fee_schedule_items = @procedure_code.organization_fee_schedule_items
                                        .joins(:organization_fee_schedule)
                                        .includes(:organization_fee_schedule)
                                        .limit(10)
  end

  def new
    @procedure_code = ProcedureCode.new
  end

  def create
    @procedure_code = ProcedureCode.new(procedure_code_params)

    if @procedure_code.save
      redirect_to admin_procedure_code_path(@procedure_code), notice: "Procedure code created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @procedure_code.update(procedure_code_params)
      redirect_to admin_procedure_code_path(@procedure_code), notice: "Procedure code updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @procedure_code.discard
      redirect_to admin_procedure_codes_path, notice: "Procedure code deleted successfully."
    else
      redirect_to admin_procedure_code_path(@procedure_code), alert: "Failed to delete procedure code."
    end
  end

  def toggle_status
    if @procedure_code.can_be_retired? || @procedure_code.can_be_activated?
      @procedure_code.toggle_status!
      redirect_to admin_procedure_code_path(@procedure_code),
                  notice: "Procedure code status changed to #{@procedure_code.status.humanize}."
    else
      redirect_to admin_procedure_code_path(@procedure_code),
                  alert: "Cannot change status - procedure code is referenced by claims."
    end
  end

  private

  def set_procedure_code
    @procedure_code = ProcedureCode.kept.find(params[:id])
  end

  def procedure_code_params
    params.require(:procedure_code).permit(:code, :description, :code_type, :status)
  end
end
