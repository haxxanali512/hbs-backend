class Admin::ProcedureCodesController < Admin::BaseController
  before_action :set_procedure_code, only: [ :show, :edit, :update, :destroy, :toggle_status, :push_to_ezclaim ]

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
    @procedure_code.build_procedure_code_rule
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
    @procedure_code.build_procedure_code_rule unless @procedure_code.procedure_code_rule
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

  def push_to_ezclaim
    # Get the first organization with EZClaim enabled (or use current user's organization)
    organization = current_user&.organizations&.first

    unless organization&.organization_setting&.ezclaim_enabled?
      redirect_to admin_procedure_code_path(@procedure_code), alert: "EZClaim is not enabled for this organization."
      return
    end

    begin
      service = EzclaimService.new(organization: organization)

      # Map procedure code fields to EZClaim fields
      procedure_code_data = {
        ProcCode: @procedure_code.code,
        ProcDescription: @procedure_code.description,
        ProcModifier: nil, # Not available in model
        ProcCharge: nil, # Not available in model
        ProcModifiersCC: nil, # Not available in model
        ProcPayFID: nil, # Not available in model
        ProcUnits: nil, # Not available in model
        ProcModifier4: nil, # Not available in model
        ProcModifier1: nil # Not available in model
      }

      result = service.create_procedure_code(procedure_code_data)

      if result[:success]
        redirect_to admin_procedure_code_path(@procedure_code), notice: "Procedure code successfully pushed to EZClaim."
      else
        redirect_to admin_procedure_code_path(@procedure_code), alert: "Failed to push procedure code to EZClaim: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Error pushing procedure code #{@procedure_code.id} to EZClaim: #{e.message}"
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to admin_procedure_code_path(@procedure_code), alert: "Error pushing procedure code to EZClaim: #{e.message}"
    end
  end

  private

  def set_procedure_code
    @procedure_code = ProcedureCode.kept.find(params[:id])
  end

  def procedure_code_params
    params.require(:procedure_code).permit(
      :code,
      :description,
      :code_type,
      :status,
      :push_to_ezclaim,
      procedure_code_rule_attributes: [
        :id,
        :time_based,
        :pricing_type,
        :special_rules_text
      ]
    )
  end
end
