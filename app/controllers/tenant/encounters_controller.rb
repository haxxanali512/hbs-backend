class Tenant::EncountersController < Tenant::BaseController
  include ProcedureCodeSearch
  before_action :set_current_organization
  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :confirm_completed, :cancel, :request_correction, :attach_document, :billing_data, :procedure_codes_search, :submit_for_billing ]
  before_action :load_form_options, only: [ :index, :new, :create, :edit, :update ]

  def index
    @encounters = @current_organization.encounters.includes(:patient, :provider, :specialty, :organization_location, :appointment).kept

    # Filtering
    @encounters = @encounters.by_status(params[:status]) if params[:status].present?
    @encounters = @encounters.by_provider(params[:provider_id]) if params[:provider_id].present?
    @encounters = @encounters.by_patient(params[:patient_id]) if params[:patient_id].present?
    @encounters = @encounters.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
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

  def new
    @encounter = @current_organization.encounters.build
    @encounter.date_of_service = Date.current
    @encounter.billing_channel = :insurance
  end

  def create
    @encounter = @current_organization.encounters.build(encounter_params)
    @encounter.confirmed_by = current_user if params[:confirm_now]

    if @encounter.save
      # Handle document uploads
      upload_documents if params.dig(:encounter, :documents).present?

      if params[:confirm_now] && @encounter.can_be_confirmed?
        @encounter.confirm_completed!
      end
      redirect_to tenant_encounter_path(@encounter), notice: "Encounter created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @encounter.update(encounter_params)
      # Handle document uploads
      upload_documents if params.dig(:encounter, :documents).present?

      redirect_to tenant_encounter_path(@encounter), notice: "Encounter updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @encounter.discard
      redirect_to tenant_encounters_path, notice: "Encounter deleted successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to delete encounter."
    end
  end

  def confirm_completed
    @encounter.confirmed_by = current_user
    return unless @encounter.may_confirm_completed? || @encounter.planned?
    @encounter.confirm_completed!
    redirect_to tenant_encounter_path(@encounter), notice: "Encounter confirmed and billing documents generated."
  end

  def cancel
    if @encounter.cancel!
      redirect_to tenant_encounter_path(@encounter), notice: "Encounter cancelled successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to cancel encounter."
    end
  end

  def request_correction
    if @encounter.cascaded?
      # Create a task for correction request
      # Placeholder: This would create an EncounterTask or similar
      redirect_to tenant_encounter_path(@encounter), notice: "Correction request submitted."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Cannot request correction for non-cascaded encounter."
    end
  end

  def billing_data
    service = ClaimSubmissionService.new(
      encounter: @encounter,
      organization: @current_organization
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
    ezclaim_service = EzclaimService.new(organization: @current_organization)
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
    @current_organization
  end

  def current_encounter_for_pricing
    @encounter
  end

  def procedure_codes_search_path_for_encounter
    procedure_codes_search_tenant_encounter_path(@encounter)
  end

  def submit_for_billing
    service = ClaimSubmissionService.new(
      encounter: @encounter,
      organization: @current_organization
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
          redirect_to tenant_encounter_path(@encounter), notice: notice_message
        else
          redirect_to tenant_encounter_path(@encounter), alert: "Failed to submit for billing: #{result[:error]}"
        end
      end
      format.json do
        if result[:success]
          render json: {
            success: true,
            message: "Encounter submitted for billing successfully.",
            redirect_url: tenant_encounter_path(@encounter)
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

  def attach_document
    unless @encounter.cascaded? && @encounter.claim.present? && (@encounter.claim.submitted? || @encounter.claim.accepted? || @encounter.claim.denied?)
      return redirect_to tenant_encounter_path(@encounter), alert: "Attachments allowed only after claim submission."
    end

    result = DocumentUploadService.new(
      documentable: @encounter,
      uploaded_by: current_user,
      organization: @current_organization,
      params: {
        file: params.dig(:document, :file),
        title: params.dig(:document, :title),
        document_type: params.dig(:document, :document_type),
        description: params.dig(:document, :description)
      }
    ).call

    if result[:success]
      redirect_to tenant_encounter_path(@encounter), notice: "Attachment uploaded successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to upload attachment: #{result[:error]}"
    end
  end

  private

  def set_encounter
    @encounter = @current_organization.encounters.kept.find(params[:id])
  end

  def load_form_options
    @providers = @current_organization.providers.kept.active.order(:first_name, :last_name)
    @patients = @current_organization.patients.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
    @locations = @current_organization.organization_locations.active.order(:name)
    @appointments = @current_organization.appointments.upcoming.order(scheduled_start_at: :asc)
    @diagnosis_codes = DiagnosisCode.active.order(:code)

    if action_name == "index"
      @statuses = Encounter.statuses.keys
      @billing_channels = Encounter.billing_channels.keys
      @show_time_filter = false
    end
  end

  def encounter_params
    params.require(:encounter).permit(
      :organization_location_id,
      :appointment_id,
      :provider_id,
      :patient_id,
      :specialty_id,
      :date_of_service,
      :billing_channel,
      :notes,
      diagnosis_code_ids: []
    )
  end

  def upload_documents
    documents = params.dig(:encounter, :documents)
    return unless documents.is_a?(Array)

    documents.each do |file|
      next if file.blank?

      DocumentUploadService.new(
        documentable: @encounter,
        uploaded_by: current_user,
        organization: @current_organization,
        params: {
          file: file,
          title: file.original_filename,
          document_type: params[:document_type] || "clinical_notes",
          description: "Uploaded with encounter creation"
        }
      ).call
    end
  end
end
