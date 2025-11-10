class Admin::EncountersController < Admin::BaseController
  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :cancel, :override_validation, :request_correction ]
  before_action :load_form_options, only: [ :index, :edit, :update ]

  def index
    @encounters = Encounter.includes(:organization, :patient, :provider, :specialty, :organization_location, :appointment).kept

    # Filtering by organization
    @encounters = @encounters.where(organization_id: params[:organization_id]) if params[:organization_id].present?

    # Filtering by status
    @encounters = @encounters.by_status(params[:status]) if params[:status].present?

    # Filtering by provider
    @encounters = @encounters.by_provider(params[:provider_id]) if params[:provider_id].present?

    # Filtering by patient
    @encounters = @encounters.by_patient(params[:patient_id]) if params[:patient_id].present?

    # Filtering by specialty
    @encounters = @encounters.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    # Filtering by billing channel
    @encounters = @encounters.by_billing_channel(params[:billing_channel]) if params[:billing_channel].present?

    if params[:cascaded_filter] == "cascaded"
      @encounters = @encounters.cascaded
    elsif params[:cascaded_filter] == "not_cascaded"
      @encounters = @encounters.not_cascaded
    end

    # Date range filter
    if params[:date_from].present? && params[:date_to].present?
      @encounters = @encounters.where(
        "date_of_service >= ? AND date_of_service <= ?",
        params[:date_from],
        params[:date_to]
      )
    elsif params[:date_from].present?
      @encounters = @encounters.where("date_of_service >= ?", params[:date_from])
    elsif params[:date_to].present?
      @encounters = @encounters.where("date_of_service <= ?", params[:date_to])
    end

    # Search
    if params[:search].present?
      # Placeholder for search functionality
      search_term = "%#{params[:search]}%"
      @encounters = @encounters.joins(:patient)
        .where("patients.first_name ILIKE ? OR patients.last_name ILIKE ?", search_term, search_term)
    end

    # Sorting
    case params[:sort]
    when "date_desc"
      @encounters = @encounters.order(date_of_service: :desc)
    when "date_asc"
      @encounters = @encounters.order(date_of_service: :asc)
    when "status"
      @encounters = @encounters.order(status: :asc)
    else
      @encounters = @encounters.recent
    end

    # Pagination
    @pagy, @encounters = pagy(@encounters, items: 20)
  end

  def show
    # Mark comments as seen when viewing encounter
    if current_user
      EncounterCommentSeen.mark_as_seen(@encounter.id, current_user.id)
    end
  end

  def edit; end

  def update
    if @encounter.update(encounter_params)
      redirect_to admin_encounter_path(@encounter), notice: "Encounter updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @encounter.discard
      redirect_to admin_encounters_path, notice: "Encounter deleted successfully."
    else
      redirect_to admin_encounter_path(@encounter), alert: "Failed to delete encounter."
    end
  end

  def cancel
    if @encounter.cancel!
      redirect_to admin_encounter_path(@encounter), notice: "Encounter cancelled successfully."
    else
      redirect_to admin_encounter_path(@encounter), alert: "Failed to cancel encounter."
    end
  end

  def override_validation
    # HBS Admin/Super only action - override validation errors
    # This is a placeholder for the actual override logic
    redirect_to admin_encounter_path(@encounter), notice: "Validation overridden."
  end

  def request_correction
    if @encounter.cascaded?
      # Create correction request task
      redirect_to admin_encounter_path(@encounter), notice: "Correction request logged."
    else
      redirect_to admin_encounter_path(@encounter), alert: "Cannot request correction for non-cascaded encounter."
    end
  end

  private

  def set_encounter
    @encounter = Encounter.kept.find(params[:id])
  end

  def load_form_options
    @organizations = Organization.kept.order(:name)
    @providers = Provider.kept.active.order(:first_name, :last_name)
    @patients = Patient.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
    @locations = OrganizationLocation.active.order(:name)
    @diagnosis_codes = DiagnosisCode.active.order(:code)

    if action_name == "index"
      @statuses = Encounter.statuses.keys
      @billing_channels = Encounter.billing_channels.keys
    end
  end

  def encounter_params
    params.require(:encounter).permit(
      :organization_id,
      :organization_location_id,
      :appointment_id,
      :provider_id,
      :patient_id,
      :specialty_id,
      :date_of_service,
      :billing_channel,
      :notes,
      :display_status,
      diagnosis_code_ids: []
    )
  end
end
