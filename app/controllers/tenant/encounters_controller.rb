class Tenant::EncountersController < Tenant::BaseController
  include ProcedureCodeSearch
  include Tenant::Concerns::EncounterIndexConcern
  before_action :set_current_organization
  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :mark_reviewed, :mark_ready_to_submit, :cancel, :request_correction, :attach_document, :billing_data, :procedure_codes_search, :diagnosis_codes_search, :submit_for_billing, :download_edi ]
  before_action :load_form_options, only: [ :index, :new, :create, :edit, :update, :workflow ]

  def index
    build_encounters_index
    @show_queued_only = params[:submitted_filter] == "queued"

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def templates_for_specialty
    specialty_id = params[:specialty_id].presence

    templates = EncounterTemplate.active
                                 .includes(:specialty, encounter_template_lines: :procedure_code)
                                 .order(:name)
    templates = templates.where(specialty_id: specialty_id) if specialty_id.present?

    data = templates.map do |template|
      {
        id: template.id,
        name: template.name,
        specialty_id: template.specialty_id,
        specialty_name: template.specialty&.name,
        lines: template.encounter_template_lines.sort_by(&:position).map do |line|
          {
            id: line.id,
            procedure_code_id: line.procedure_code_id,
            code: line.procedure_code.code,
            description: line.procedure_code.description,
            units: line.units,
            modifiers: line.modifiers
          }
        end
      }
    end

    render json: { success: true, templates: data }
  end

  def show
    # Mark comments as seen when viewing encounter
    if current_user
      EncounterCommentSeen.mark_as_seen(@encounter.id, current_user.id)
    end
  end

  def new
    redirect_to workflow_tenant_encounters_path
  end

  def create
    @encounter = @current_organization.encounters.build(encounter_params)

    if @encounter.save
      # Skip review status and mark as ready_to_submit directly
      # First mark as ready_for_review (required for validation)
      if @encounter.may_mark_ready_for_review?
        @encounter.mark_ready_for_review!
        # Then immediately mark as reviewed
        if @encounter.may_mark_reviewed?
          @encounter.mark_reviewed!
          # Finally mark as ready to submit
          @encounter.mark_ready_to_submit! if @encounter.may_mark_ready_to_submit?
        end
      end
      load_workflow_collections

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "prepare_encounter_frame",
              partial: "tenant/encounters/workflow_form",
              locals: {
                encounter: @current_organization.encounters.build(date_of_service: Date.current, billing_channel: :insurance),
                patients: @patients,
                providers: @providers,
                specialties: @specialties,
                locations: @locations,
                appointments: @appointments,
                diagnosis_codes: @diagnosis_codes
              }
            ),
            turbo_stream.replace(
              "queued_encounters_frame",
              partial: "tenant/encounters/queued_table",
              locals: { queued_encounters: @queued_encounters }
            ),
            turbo_stream.prepend(
              "flash",
              partial: "shared/flash_message",
              locals: {
                type: :notice,
                message: "Encounter saved and ready to submit."
              }
            )
          ]
        end
        format.html { redirect_to workflow_tenant_encounters_path, notice: "Encounter saved for submission." }
      end
    else
      load_workflow_collections
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "prepare_encounter_frame",
            partial: "tenant/encounters/workflow_form",
            locals: {
              encounter: @encounter,
              patients: @patients,
              providers: @providers,
              specialties: @specialties,
              locations: @locations,
              appointments: @appointments,
              diagnosis_codes: @diagnosis_codes
            }
          )
        end
        format.html { render :workflow, status: :unprocessable_entity }
      end
    end
  end

  def edit
    # Populate virtual attributes for the form
    @encounter.diagnosis_code_ids = @encounter.diagnosis_codes.pluck(:id)
    @encounter.procedure_code_ids = @encounter.encounter_procedure_items.pluck(:procedure_code_id)
    @encounter.primary_procedure_code_id = @encounter.encounter_procedure_items.primary.first&.procedure_code_id
  end

  def update
    if @encounter.update(encounter_params)
      # Handle document uploads
      upload_documents if params.dig(:encounter, :documents).present?

      # Ensure encounter is still ready_to_submit after update
      if @encounter.ready_for_review? && @encounter.may_mark_reviewed?
        @encounter.mark_reviewed!
        @encounter.mark_ready_to_submit! if @encounter.may_mark_ready_to_submit?
      elsif @encounter.reviewed? && @encounter.may_mark_ready_to_submit?
        @encounter.mark_ready_to_submit!
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "prepare_encounter_frame",
              partial: "tenant/encounters/workflow_form",
              locals: {
                encounter: @encounter,
                patients: @patients,
                providers: @providers,
                specialties: @specialties,
                locations: @locations,
                appointments: @appointments,
                diagnosis_codes: @diagnosis_codes
              }
            ),
            turbo_stream.prepend(
              "flash",
              partial: "shared/flash_message",
              locals: {
                type: :notice,
                message: "Encounter updated successfully."
              }
            )
          ]
        end
        format.html { redirect_to tenant_encounter_path(@encounter), notice: "Encounter updated successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "prepare_encounter_frame",
            partial: "tenant/encounters/workflow_form",
            locals: {
              encounter: @encounter,
              patients: @patients,
              providers: @providers,
              specialties: @specialties,
              locations: @locations,
              appointments: @appointments,
              diagnosis_codes: @diagnosis_codes
            }
          )
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @encounter.discard
      redirect_to tenant_encounters_path, notice: "Encounter deleted successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to delete encounter."
    end
  end

  def mark_reviewed
    @encounter.reviewed_by = current_user if @encounter.respond_to?(:reviewed_by=)

    if @encounter.may_mark_reviewed? && @encounter.mark_reviewed!
      redirect_to tenant_encounter_path(@encounter), notice: "Encounter marked as reviewed."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to mark encounter as reviewed."
    end
  end

  def mark_ready_to_submit
    if @encounter.may_mark_ready_to_submit? && @encounter.mark_ready_to_submit!
      redirect_to tenant_encounters_path(submitted_filter: "queued"), notice: "Encounter is now ready to be sent to billing."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to mark encounter as ready to submit."
    end
  end

  def cancel
    if @encounter.cancel!
      redirect_to tenant_encounter_path(@encounter), notice: "Encounter cancelled successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to cancel encounter."
    end
  end

  def workflow
    @encounter = @current_organization.encounters.build(
      date_of_service: Date.current,
      billing_channel: :insurance
    )

    # Auto-populate patient if patient_id is provided
    if params[:patient_id].present?
      patient = @current_organization.patients.find_by(id: params[:patient_id])
      if patient
        @encounter.patient_id = patient.id
      end
    end

    load_workflow_collections
  end

  def specialties_for_provider
    provider = @current_organization.providers.kept.active.find_by(id: params[:provider_id])
    return render json: { success: false, specialties: [] } unless provider

    specialties = provider.specialties.kept.active.order(:name)
    data = specialties.map { |s| { id: s.id, name: s.name } }

    render json: { success: true, specialties: data }
  end

  def load_workflow_collections
    # Show encounters that are ready to submit (ready_to_submit but not yet cascaded)
    @queued_encounters = @current_organization.encounters
                                             .kept
                                             .where(status: :ready_to_submit)
                                             .where(cascaded: false)
                                             .includes(:patient, :provider, :diagnosis_codes, :encounter_procedure_items, :procedure_codes, claim: { claim_lines: :procedure_code })
                                             .order(created_at: :desc)
  end


  def submit_queued
    # Handle both array and comma-separated string formats
    encounter_ids = if params[:encounter_ids].is_a?(Array)
      params[:encounter_ids].reject(&:blank?)
    elsif params[:encounter_ids].is_a?(String)
      params[:encounter_ids].split(",").reject(&:blank?)
    else
      []
    end

    if encounter_ids.empty?
      respond_to do |format|
        format.html do
          flash[:alert] = "Please select at least one encounter to submit."
          redirect_to tenant_encounters_path(submitted_filter: "queued"), status: :see_other
        end
        format.turbo_stream do
          flash.now[:alert] = "Please select at least one encounter to submit."
          @show_queued_only = true
          build_encounters_index
          render turbo_stream: [
            turbo_stream.replace("encounters_table_frame", partial: "tenant/encounters/table", locals: { encounters: @encounters, show_submitted_only: false, show_queued_only: true, pagy: @pagy }),
            turbo_stream.replace("flash_container", partial: "shared/toast_flash")
          ]
        end
      end
      return
    end

    # Validate that all encounters belong to the current organization and are ready to submit
    # Only ready_to_submit encounters that haven't been cascaded can be submitted
    valid_encounters = @current_organization.encounters
                                            .where(id: encounter_ids)
                                            .where(status: :ready_to_submit)
                                            .where(cascaded: false)
                                            .to_a

    if valid_encounters.size != encounter_ids.count
      respond_to do |format|
        format.html do
          flash[:alert] = "Some selected encounters are not valid for submission."
          redirect_to tenant_encounters_path(submitted_filter: "queued"), status: :see_other
        end
        format.turbo_stream do
          flash.now[:alert] = "Some selected encounters are not valid for submission."
          @show_queued_only = true
          build_encounters_index
          render turbo_stream: [
            turbo_stream.replace("encounters_table_frame", partial: "tenant/encounters/table", locals: { encounters: @encounters, show_submitted_only: false, show_queued_only: true, pagy: @pagy }),
            turbo_stream.replace("flash_container", partial: "shared/toast_flash")
          ]
        end
      end
      return
    end

    # Queue the job to process submissions in the background
    # The job will:
    # 1. Mark encounters as "sent" when actually submitting to Waystar
    # 2. Change them to "completed_confirmed" after successful submission
    QueuedEncountersSubmissionJob.perform_later(encounter_ids, @current_organization.id)
    Rails.logger.info "Queued #{encounter_ids.size} encounter(s) for background processing to Waystar via EDI 837"

    # Notify super admins about the submission
    NotificationService.notify_encounters_submitted_for_billing(
      organization: @current_organization,
      encounter_count: valid_encounters.size
    )

    respond_to do |format|
      format.html do
        flash[:notice] = "#{valid_encounters.size} encounter(s) queued for billing submission."
        redirect_to tenant_encounters_path(submitted_filter: "queued"), status: :see_other
      end
      format.turbo_stream do
        # Reload the queued encounters table (should now be empty or show remaining items)
        @show_queued_only = true
        params[:submitted_filter] = "queued"
        build_encounters_index
        flash.now[:notice] = "#{valid_encounters.size} encounter(s) queued for billing submission."
        render :index
      end
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

    # Add diagnosis code IDs to payload for proper multi-select initialization
    diagnosis_codes = @encounter.diagnosis_codes.limit(4).to_a
    diagnosis_payload = {}
    diagnosis_codes.each_with_index do |dc, index|
      diagnosis_payload["ClaDiagnosis#{index + 1}"] = dc.code
      diagnosis_payload["diagnosis_#{index + 1}_id"] = dc.id
    end

    # Combine claim payload with service lines and diagnosis codes
    combined_payload = claim_payload.merge(
      service_LinesObjectWithoutID: formatted_service_lines
    ).merge(diagnosis_payload)

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

  def diagnosis_codes_search
    search_term = params[:q] || params[:search] || ""

    diagnosis_codes = DiagnosisCode.active
                                   .search(search_term)
                                   .limit(50)
                                   .order(:code)

    render json: {
      success: true,
      results: diagnosis_codes.map do |dc|
        {
          id: dc.id,
          code: dc.code || "",
          description: dc.description || "",
          display: "#{dc.code || 'N/A'} - #{dc.description || 'No description'}"
        }
      end
    }
  rescue => e
    Rails.logger.error("Error in diagnosis_codes_search: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
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

  def download_edi
    claim = @encounter.claim
    unless claim&.edi_file&.attached?
      redirect_to tenant_encounter_path(@encounter), alert: "EDI file not found for this encounter."
      return
    end

    redirect_to rails_blob_path(claim.edi_file, disposition: "attachment")
  end

  private

  def set_encounter
    @encounter = @current_organization.encounters
                                      .kept
                                      .includes(:patient, :provider, :specialty, :diagnosis_codes, :encounter_procedure_items, :procedure_codes)
                                      .find(params[:id])
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
      :encounter_template_id,
      :primary_procedure_code_id,
      :place_of_service_code,
      diagnosis_code_ids: [],
      procedure_code_ids: [],
      procedure_units: {},
      procedure_modifiers: {}
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
