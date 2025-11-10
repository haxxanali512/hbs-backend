class Tenant::EncountersController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_encounter, only: [ :show, :edit, :update, :destroy, :confirm_completed, :cancel, :request_correction, :attach_document ]
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
end
