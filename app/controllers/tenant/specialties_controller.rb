class Tenant::SpecialtiesController < Tenant::BaseController
  before_action :set_specialty, only: [ :show, :edit, :update, :destroy ]

  def index
    @specialties = Specialty.active.kept.includes(:procedure_codes)
                            .order(:name)

    # Apply filters
    @specialties = @specialties.search(params[:search]) if params[:search].present?
    @specialties = @specialties.by_name(params[:name]) if params[:name].present?
    @specialties = @specialties.where(status: params[:status]) if params[:status].present?

    # Get enabled specialty IDs for the view to determine locked/enabled status
    fee_schedule = @current_organization.get_or_create_fee_schedule
    @enabled_specialty_ids = fee_schedule.specialties.kept.pluck(:id)

    @pagy, @specialties = pagy(@specialties, items: 20)
  end

  def show
    @providers = @current_organization.providers.kept
                                     .joins(:specialties)
                                     .where(specialties: { id: @specialty.id })
                                     .order(:first_name, :last_name)
  end

  def new
    @specialty = Specialty.new
    @procedure_codes = ProcedureCode.kept.active.order(:code)
  end

  def create
    @specialty = Specialty.new(specialty_params)

    if @specialty.save
      # Handle procedure code assignments (allow from all active procedure codes)
      if params[:specialty][:procedure_code_ids].present?
        allowed_code_ids = ProcedureCode.kept.active.pluck(:id)
        selected_code_ids = params[:specialty][:procedure_code_ids].map(&:to_i) & allowed_code_ids
        @specialty.procedure_code_ids = selected_code_ids
      end

      # Automatically assign specialty to organization's fee schedule
      fee_schedule = @current_organization.get_or_create_fee_schedule
      unless fee_schedule.specialties.include?(@specialty)
        fee_schedule.specialties << @specialty
      end

      # Automatically unlock procedure codes for this specialty
      if @specialty.active?
        FeeScheduleUnlockService.unlock_procedure_codes_for_organization(@current_organization, @specialty)
      end

      redirect_to tenant_specialty_path(@specialty), notice: "Specialty created successfully and assigned to your organization."
    else
      @procedure_codes = ProcedureCode.kept.active.order(:code)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @procedure_codes = ProcedureCode.kept.active.order(:code)
  end

  def update
    if @specialty.update(specialty_params)
      # Handle procedure code assignments (allow from all active procedure codes)
      if params[:specialty][:procedure_code_ids].present?
        allowed_code_ids = ProcedureCode.kept.active.pluck(:id)
        selected_code_ids = params[:specialty][:procedure_code_ids].map(&:to_i) & allowed_code_ids
        @specialty.procedure_code_ids = selected_code_ids
      end

      # Ensure specialty is assigned to organization's fee schedule
      fee_schedule = @current_organization.get_or_create_fee_schedule
      unless fee_schedule.specialties.include?(@specialty)
        fee_schedule.specialties << @specialty
      end

      # Update unlocked procedure codes if specialty is active
      if @specialty.active?
        FeeScheduleUnlockService.unlock_procedure_codes_for_organization(@current_organization, @specialty)
      else
        # If specialty is retired, check and deactivate codes
        FeeScheduleUnlockService.check_and_deactivate_unlocked_codes(@current_organization)
      end

      redirect_to tenant_specialty_path(@specialty), notice: "Specialty updated successfully."
    else
      @procedure_codes = ProcedureCode.kept.active.order(:code)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @specialty.can_be_deleted?
      @specialty.discard
      redirect_to tenant_specialties_path, notice: "Specialty deleted successfully."
    else
      redirect_to tenant_specialty_path(@specialty), alert: "Cannot delete specialty with assigned providers."
    end
  end

  def add_selected
    specialty_ids = params[:specialty_ids] || []

    if specialty_ids.empty?
      redirect_to tenant_specialties_path, alert: "Please select at least one specialty to add."
      return
    end

    fee_schedule = @current_organization.get_or_create_fee_schedule
    added_count = 0

    specialty_ids.each do |specialty_id|
      specialty = Specialty.kept.find_by(id: specialty_id)
      next unless specialty&.active?

      unless fee_schedule.specialties.include?(specialty)
        fee_schedule.specialties << specialty
        # Unlock procedure codes for this specialty
        FeeScheduleUnlockService.unlock_procedure_codes_for_organization(@current_organization, specialty)
        added_count += 1
      end
    end

    if added_count > 0
      redirect_to tenant_specialties_path, notice: "Successfully added #{added_count} #{'specialty'.pluralize(added_count)} to your organization."
    else
      redirect_to tenant_specialties_path, alert: "No new specialties were added. They may already be enabled or are not active."
    end
  end

  private

  def set_specialty
    @specialty = Specialty.kept.find(params[:id])
  end

  def specialty_params
    params.require(:specialty).permit(:name, :description, :status, procedure_code_ids: [])
  end
end
