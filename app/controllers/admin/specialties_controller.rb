class Admin::SpecialtiesController < Admin::BaseController
  before_action :set_specialty, only: [ :show, :edit, :update, :destroy, :retire, :impact_analysis ]

  def index
    @specialties = Specialty.kept.includes(:procedure_codes, :providers)
                            .order(:name)

    # Apply filters
    @specialties = @specialties.search(params[:search]) if params[:search].present?
    @specialties = @specialties.where(status: params[:status]) if params[:status].present?
    @specialties = @specialties.by_name(params[:name]) if params[:name].present?

    @pagy, @specialties = pagy(@specialties, items: 20)
  end

  def show
    @impact_analysis = @specialty.impact_analysis
  end

  def new
    @specialty = Specialty.new
    @procedure_codes = ProcedureCode.order(:code)
  end

  def create
    @specialty = Specialty.new(specialty_params)

    if @specialty.save
      # Handle procedure code assignments
      if params[:specialty][:procedure_code_ids].present?
        @specialty.procedure_code_ids = params[:specialty][:procedure_code_ids]
      end

      redirect_to admin_specialty_path(@specialty), notice: "Specialty created successfully."
    else
      @procedure_codes = ProcedureCode.order(:code)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @procedure_codes = ProcedureCode.order(:code)
  end

  def update
    if @specialty.update(specialty_params)
      # Handle procedure code assignments
      if params[:specialty][:procedure_code_ids].present?
        @specialty.procedure_code_ids = params[:specialty][:procedure_code_ids]
      end

      redirect_to admin_specialty_path(@specialty), notice: "Specialty updated successfully."
    else
      @procedure_codes = ProcedureCode.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @specialty.can_be_deleted?
      @specialty.discard
      redirect_to admin_specialties_path, notice: "Specialty deleted successfully."
    else
      redirect_to admin_specialty_path(@specialty), alert: "Cannot delete specialty with assigned providers."
    end
  end

  def retire
    result = SpecialtyService.retire_specialty(@specialty, current_user)

    if result[:success]
      redirect_to admin_specialty_path(@specialty), notice: result[:message]
    else
      redirect_to admin_specialty_path(@specialty), alert: result[:error]
    end
  end

  def impact_analysis
    @impact_analysis = SpecialtyService.impact_analysis(@specialty)
    render json: @impact_analysis
  end

  def update_allowed_codes
    @specialty = Specialty.find(params[:id])
    authorize @specialty
    procedure_code_ids = params[:specialty][:procedure_code_ids] || []

    if @specialty.update(procedure_code_ids: procedure_code_ids)
      redirect_to admin_specialty_path(@specialty), notice: "Allowed CPT codes updated successfully."
    else
      redirect_to admin_specialty_path(@specialty), alert: "Failed to update allowed CPT codes."
    end
  end

  def list_providers
    @specialty = Specialty.find(params[:id])
    authorize @specialty
    @providers = @specialty.providers.includes(:organizations, :user)
                          .order(:first_name, :last_name)

    @pagy, @providers = pagy(@providers, items: 20)
  end

  private

  def set_specialty
    @specialty = Specialty.kept.find(params[:id])
  end

  def specialty_params
    params.require(:specialty).permit(:name, :description, :status, procedure_code_ids: [])
  end
end
