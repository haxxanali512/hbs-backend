class Admin::EncountersController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration
  include Admin::Concerns::EncounterConcern

  # Alias the concern method before we override it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :cancel, :override_validation, :request_correction ]
  before_action :load_form_options, only: [ :index, :edit, :update ]

  def index
    @encounters = build_encounters_index_query
    @encounters = apply_encounters_filters(@encounters)
    @encounters = apply_encounters_sorting(@encounters)
    @pagy, @encounters = paginate_encounters(@encounters)
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

  def fetch_from_ezclaim
    fetch_from_ezclaim_concern(resource_type: :encounters, service_method: :get_encounters)
  end

  def save_from_ezclaim
    save_encounters_from_ezclaim
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
