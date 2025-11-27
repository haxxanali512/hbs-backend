class Admin::PatientsController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration

  # Alias concern method before overriding it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_patient, only: [ :show, :edit, :update, :destroy, :activate, :inactivate, :mark_deceased, :reactivate ]

  def index
    @patients = Patient.includes(:organization).kept

    # Filtering by organization
    @patients = @patients.where(organization_id: params[:organization_id]) if params[:organization_id].present?

    # Filtering by status
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
    @organizations = Organization.kept.order(:name)
    @statuses = Patient.statuses.keys
  end

  def show; end

  def edit; end

  def update
    if @patient.update(patient_params)
      redirect_to admin_patient_path(@patient), notice: "Patient updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @patient.can_be_deleted? && @patient.discard
      redirect_to admin_patients_path, notice: "Patient deleted successfully."
    else
      redirect_to admin_patient_path(@patient), alert: "Cannot delete patient. They have appointments or encounters, or are deceased."
    end
  end

  def activate
    if @patient.activate!
      redirect_to admin_patient_path(@patient), notice: "Patient activated successfully."
    else
      redirect_to admin_patient_path(@patient), alert: "Failed to activate patient."
    end
  end

  def inactivate
    if @patient.inactivate!
      redirect_to admin_patient_path(@patient), notice: "Patient inactivated successfully."
    else
      redirect_to admin_patient_path(@patient), alert: "Failed to inactivate patient."
    end
  end

  def mark_deceased
    if @patient.mark_deceased!
      redirect_to admin_patient_path(@patient), notice: "Patient marked as deceased."
    else
      redirect_to admin_patient_path(@patient), alert: "Failed to mark patient as deceased."
    end
  end

  def reactivate
    if @patient.reactivate!
      redirect_to admin_patient_path(@patient), notice: "Patient reactivated successfully."
    else
      redirect_to admin_patient_path(@patient), alert: "Failed to reactivate patient."
    end
  end

  def fetch_from_ezclaim
    fetch_from_ezclaim_concern(resource_type: :patients, service_method: :get_patients)
  end

  def save_from_ezclaim
    save_patients_from_ezclaim
  end

  private

  def set_patient
    @patient = Patient.kept.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :organization_id,
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
