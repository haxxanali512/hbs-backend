class Tenant::PatientsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_patient, only: [ :show, :edit, :update, :destroy, :activate, :inactivate, :mark_deceased, :reactivate ]

  def index
    @patients = @current_organization.patients.includes(:organization).kept

    # Filtering
    @patients = @patients.by_status(params[:status]) if params[:status].present?

    # Search
    if params[:search].present?
      @patients = @patients.search(params[:search])
    end

    # Sorting
    case params[:sort]
    when "name_asc"
      @patients = @patients.order(:first_name, :last_name)
    when "name_desc"
      @patients = @patients.order(first_name: :desc, last_name: :desc)
    when "created_desc"
      @patients = @patients.order(created_at: :desc)
    else
      @patients = @patients.recent
    end

    # Pagination
    @pagy, @patients = pagy(@patients, items: 20)

    # For filters
    @statuses = Patient.statuses.keys
  end

  def show; end

  def new
    @patient = @current_organization.patients.build
  end

  def create
    @patient = @current_organization.patients.build(patient_params)

    if @patient.save
      redirect_to tenant_patient_path(@patient), notice: "Patient created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @patient.update(patient_params)
      redirect_to tenant_patient_path(@patient), notice: "Patient updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @patient.can_be_deleted? && @patient.discard
      redirect_to tenant_patients_path, notice: "Patient deleted successfully."
    else
      redirect_to tenant_patient_path(@patient), alert: "Cannot delete patient. They have appointments or encounters, or are deceased."
    end
  end

  def activate
    if @patient.activate!
      redirect_to tenant_patient_path(@patient), notice: "Patient activated successfully."
    else
      redirect_to tenant_patient_path(@patient), alert: "Failed to activate patient: #{@patient.errors.full_messages.join(', ')}"
    end
  end

  def inactivate
    if @patient.inactivate!
      redirect_to tenant_patient_path(@patient), notice: "Patient inactivated successfully."
    else
      redirect_to tenant_patient_path(@patient), alert: "Cannot inactivate patient: #{@patient.errors.full_messages.join(', ')}"
    end
  end

  def mark_deceased
    if @patient.mark_deceased!
      redirect_to tenant_patient_path(@patient), notice: "Patient marked as deceased."
    else
      redirect_to tenant_patient_path(@patient), alert: "Failed to mark patient as deceased: #{@patient.errors.full_messages.join(', ')}"
    end
  end

  def reactivate
    if @patient.reactivate!
      redirect_to tenant_patient_path(@patient), notice: "Patient reactivated successfully."
    else
      redirect_to tenant_patient_path(@patient), alert: "Failed to reactivate patient: #{@patient.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_patient
    @patient = @current_organization.patients.kept.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :first_name,
      :last_name,
      :dob,
      :sex_at_birth,
      :address_line_1,
      :address_line_2,
      :city,
      :state,
      :postal,
      :country,
      :phone_number,
      :email,
      :mrn,
      :external_id,
      :status,
      :notes_nonphi
    )
  end
end
