class Tenant::PrescriptionsController < Tenant::BaseController
  include PrescriptionsExpirationExportable

  before_action :set_prescription, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]
  before_action :load_form_options, only: [ :new, :edit, :create, :update ]

  def index
    @prescriptions = base_scope
    @prescriptions = apply_filters(@prescriptions)

    # Search
    if params[:search].present?
      @prescriptions = @prescriptions.joins(:patient).where(
        "patients.first_name ILIKE ? OR patients.last_name ILIKE ? OR prescriptions.title ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    @pagy, @prescriptions = pagy(@prescriptions, items: 20)
  end

  def export
    prescriptions = apply_filters(base_scope)
    if params[:search].present?
      prescriptions = prescriptions.joins(:patient).where(
        "patients.first_name ILIKE ? OR patients.last_name ILIKE ? OR prescriptions.title ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    csv_data = prescriptions_to_csv(prescriptions)
    send_data csv_data,
              filename: prescription_export_filename(params[:expiration_filter]),
              type: "text/csv",
              disposition: "attachment"
  end

  def show
    @patient = @prescription.patient
  end

  def new
    @prescription = @current_organization.prescriptions.build(
      date_written: Date.current,
      patient_id: params[:patient_id]
    )
    # Ensure diagnosis codes are not loaded from previous entries
    @prescription.diagnosis_code_ids = []
    @patient = @current_organization.patients.find(params[:patient_id]) if params[:patient_id].present?
  end

  def create
    @prescription = @current_organization.prescriptions.build(prescription_params)
    @prescription.organization_id = @current_organization.id

    if @prescription.save
      redirect_to tenant_prescription_path(@prescription), notice: "Prescription created successfully."
    else
      @patient = @prescription.patient if @prescription.patient_id.present?
      render :new, status: :unprocessable_entity
    end
  end

  def specialties_for_provider
    provider = @current_organization.providers.kept.active.find_by(id: params[:provider_id])
    return render json: { success: false, specialties: [] } unless provider

    specialties = provider.specialties.kept.active.order(:name)
    data = specialties.map { |s| { id: s.id, name: s.name } }

    render json: { success: true, specialties: data }
  end

  def procedure_codes_for_specialty
    specialty = Specialty.kept.active.find_by(id: params[:specialty_id])
    return render json: { success: false, procedure_codes: [] } unless specialty

    codes = specialty.procedure_codes.kept.active.order(:code)
    data = codes.map { |pc| { id: pc.id, code: pc.code, description: pc.description } }

    render json: { success: true, procedure_codes: data }
  end

  def edit
    @patient = @prescription.patient
  end

  def update
    if @prescription.update(prescription_params)
      redirect_to tenant_prescription_path(@prescription), notice: "Prescription updated successfully."
    else
      @patient = @prescription.patient
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @prescription.discard
      redirect_to tenant_prescriptions_path, notice: "Prescription deleted successfully."
    else
      redirect_to tenant_prescription_path(@prescription), alert: "Cannot delete prescription: #{@prescription.errors.full_messages.join(', ')}"
    end
  end

  def archive
    if @prescription.archive!
      redirect_to tenant_prescription_path(@prescription), notice: "Prescription archived successfully."
    else
      redirect_to tenant_prescription_path(@prescription), alert: "Cannot archive prescription: #{@prescription.errors.full_messages.join(', ')}"
    end
  end

  def unarchive
    if @prescription.unarchive!
      redirect_to tenant_prescription_path(@prescription), notice: "Prescription unarchived successfully."
    else
      redirect_to tenant_prescription_path(@prescription), alert: "Cannot unarchive prescription: #{@prescription.errors.full_messages.join(', ')}"
    end
  end

  private

  def base_scope
    @current_organization.prescriptions
      .includes(:patient, :specialty, :procedure_code, :provider, :diagnosis_codes)
      .kept
      .order(created_at: :desc)
  end

  def apply_filters(scope)
    scope = scope.where(patient_id: params[:patient_id]) if params[:patient_id].present?
    scope = scope.where(archived: params[:archived] == "true") if params[:archived].present?
    scope = scope.where(expired: params[:expired] == "true") if params[:expired].present?
    scope = scope.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?

    if params[:expiring] == "true"
      scope = scope.where(archived: false)
        .where("expires_on BETWEEN ? AND ?", Date.current, Date.current + 30.days)
    end

    scope = apply_expiration_filter_to_scope(scope, params[:expiration_filter])
    scope
  end

  def set_prescription
    @prescription = @current_organization.prescriptions.find(params[:id])
  end

  def load_form_options
    @patients = @current_organization.patients.active.order(:last_name, :first_name)
    @specialties = Specialty.active.kept
      .joins(providers: :provider_assignments)
      .where(provider_assignments: { organization_id: @current_organization.id, active: true })
      .distinct.order(:name)
    @procedure_codes = ProcedureCode.active.order(:code)
  end

  def prescription_params
    params.require(:prescription).permit(
      :patient_id,
      :title,
      :date_written,
      :expires_on,
      :expiration_option,
      :expiration_duration_value,
      :expiration_duration_unit,
      :expiration_date,
      :specialty_id,
      :procedure_code_id,
      :provider_id,
      :archived,
      diagnosis_code_ids: [],
      documents: []
    )
  end
end
