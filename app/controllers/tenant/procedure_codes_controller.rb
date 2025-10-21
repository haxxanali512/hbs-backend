class Tenant::ProcedureCodesController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_procedure_code, only: [ :show ]

  def index
    @procedure_codes = ProcedureCode.kept
                                   .active
                                   .includes(:specialties)
                                   .order(:code_type, :code)

    # Apply filters
    @procedure_codes = @procedure_codes.search(params[:search]) if params[:search].present?
    @procedure_codes = @procedure_codes.by_code_type(params[:code_type]) if params[:code_type].present?

    @pagy, @procedure_codes = pagy(@procedure_codes, items: 20)
  end

  def show
    @specialties = @procedure_code.specialties.active.order(:name)

    # Show fee schedule items for this organization only
    @fee_schedule_items = @procedure_code.organization_fee_schedule_items
                                        .joins(:organization_fee_schedule)
                                        .where(organization_fee_schedules: { organization_id: @current_organization.id })
                                        .includes(:organization_fee_schedule)
  end

  private

  def set_procedure_code
    @procedure_code = ProcedureCode.kept.active.find(params[:id])
  end
end
