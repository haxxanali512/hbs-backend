class Admin::EncountersController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration
  include Admin::Concerns::EncounterConcern
  include ProcedureCodeSearch

  # Alias the concern method before we override it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :cancel, :override_validation, :request_correction, :billing_data, :procedure_codes_search, :submit_for_billing ]
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

  def billing_data
    service = ClaimSubmissionService.new(
      encounter: @encounter,
      organization: @encounter.organization
    )

    # Build claim payload
    claim_payload = service.send(:build_claim_payload)

    # Build service lines payload (we'll use a placeholder claim_id for preview)
    service_lines_payload = []
    begin
      service_lines_payload = service.send(:build_service_lines_payload, "PREVIEW")
    rescue => e
      # If service lines can't be built, return empty array
      Rails.logger.warn("Could not build service lines for preview: #{e.message}")
    end

    # Get EZClaim service config
    ezclaim_service = EzclaimService.new(organization: @encounter.organization)
    config = ezclaim_service.api_config

    # Format payload to match what the modal expects
    # The modal expects service_LinesObjectWithoutID array
    formatted_service_lines = service_lines_payload.map do |line|
      {
        SrvDateFrom: line[:SrvFromDate],
        SrvDateTo: line[:SrvToDate],
        SrvProcedureCode: line[:SrvProcedureCode],
        SrvProcedureUnits: line[:SrvUnits]
      }
    end

    # Combine claim payload with service lines
    combined_payload = claim_payload.merge(
      service_LinesObjectWithoutID: formatted_service_lines
    )

    render json: {
      success: true,
      api_url: config[:api_url],
      api_version: config[:api_version],
      payload: combined_payload
    }
  rescue => e
    Rails.logger.error("Error building billing data: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  # Implement abstract methods from ProcedureCodeSearch concern
  def current_organization_for_pricing
    @encounter.organization
  end

  def current_encounter_for_pricing
    @encounter
  end

  def procedure_codes_search_path_for_encounter
    procedure_codes_search_admin_encounter_path(@encounter)
  end

  def submit_for_billing
    service = ClaimSubmissionService.new(
      encounter: @encounter,
      organization: @encounter.organization
    )

    # Build and submit using service
    # Note: In the future, we could accept edited payload from modal (params[:claim])
    # and modify the service to use it instead of building from scratch
    result = service.submit_for_billing

    respond_to do |format|
      format.html do
        if result[:success]
          notice_message = "Encounter submitted for billing successfully."
          if result[:service_lines_error]
            notice_message += " Warning: Service lines submission had issues: #{result[:service_lines_error]}"
          end
          redirect_to admin_encounter_path(@encounter), notice: notice_message
        else
          redirect_to admin_encounter_path(@encounter), alert: "Failed to submit for billing: #{result[:error]}"
        end
      end
      format.json do
        if result[:success]
          render json: {
            success: true,
            message: "Encounter submitted for billing successfully.",
            redirect_url: admin_encounter_path(@encounter)
          }
        else
          render json: {
            success: false,
            error: result[:error] || "Failed to submit for billing"
          }, status: :unprocessable_entity
        end
      end
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
