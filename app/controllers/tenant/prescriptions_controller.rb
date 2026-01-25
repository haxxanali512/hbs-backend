class Tenant::PrescriptionsController < Tenant::BaseController
  before_action :set_prescription, only: [ :show, :edit, :update, :destroy, :archive, :unarchive ]
  before_action :load_form_options, only: [ :new, :edit, :create, :update ]

  def index
    @prescriptions = @current_organization.prescriptions
      .includes(:patient, :specialty, :procedure_code, :provider, :diagnosis_codes)
      .kept
      .order(created_at: :desc)

    # Filtering
    @prescriptions = @prescriptions.where(patient_id: params[:patient_id]) if params[:patient_id].present?
    @prescriptions = @prescriptions.where(archived: params[:archived] == "true") if params[:archived].present?
    @prescriptions = @prescriptions.where(expired: params[:expired] == "true") if params[:expired].present?
    @prescriptions = @prescriptions.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?

    # Search
    if params[:search].present?
      @prescriptions = @prescriptions.joins(:patient).where(
        "patients.first_name ILIKE ? OR patients.last_name ILIKE ? OR prescriptions.title ILIKE ?",
        "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%"
      )
    end

    @pagy, @prescriptions = pagy(@prescriptions, items: 20)
  end

  def show
    @patient = @prescription.patient
  end

  def new
    @prescription = @current_organization.prescriptions.build(
      date_written: Date.current,
      patient_id: params[:patient_id]
    )
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

  def set_prescription
    @prescription = @current_organization.prescriptions.find(params[:id])
  end

  def load_form_options
    @patients = @current_organization.patients.active.order(:last_name, :first_name)
    @specialties = Specialty.active.kept.order(:name)
    @procedure_codes = ProcedureCode.active.order(:code)
    @providers = @current_organization.providers.kept.active.order(:first_name, :last_name)
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
