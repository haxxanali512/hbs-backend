class Admin::AppointmentsController < Admin::BaseController
  before_action :set_appointment, only: [ :show, :edit, :update, :destroy ]
  before_action :load_filter_options, only: [ :index, :edit, :update ]

  def index
    @appointments = Appointment.includes(:organization, :patient, :provider, :specialty, :organization_location).kept

    # Filtering by organization
    @appointments = @appointments.where(organization_id: params[:organization_id]) if params[:organization_id].present?

    # Filtering by status
    @appointments = @appointments.by_status(params[:status]) if params[:status].present?

    # Filtering by provider
    @appointments = @appointments.by_provider(params[:provider_id]) if params[:provider_id].present?

    # Filtering by patient
    @appointments = @appointments.by_patient(params[:patient_id]) if params[:patient_id].present?

    # Filtering by specialty
    @appointments = @appointments.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    # Time-based filters
    if params[:time_filter] == "upcoming"
      @appointments = @appointments.upcoming
    elsif params[:time_filter] == "past"
      @appointments = @appointments.past
    elsif params[:time_filter] == "today"
      @appointments = @appointments.today
    elsif params[:time_filter] == "this_week"
      @appointments = @appointments.this_week
    elsif params[:time_filter] == "this_month"
      @appointments = @appointments.this_month
    end

    # Date range filter
    if params[:date_from].present? && params[:date_to].present?
      @appointments = @appointments.where(
        "scheduled_start_at >= ? AND scheduled_start_at <= ?",
        params[:date_from],
        params[:date_to]
      )
    elsif params[:date_from].present?
      @appointments = @appointments.where("scheduled_start_at >= ?", params[:date_from])
    elsif params[:date_to].present?
      @appointments = @appointments.where("scheduled_start_at <= ?", params[:date_to])
    end

    # Search
    if params[:search].present?
      @appointments = @appointments.search(params[:search])
    end

    # Sorting
    case params[:sort]
    when "scheduled_desc"
      @appointments = @appointments.order(scheduled_start_at: :desc)
    when "scheduled_asc"
      @appointments = @appointments.order(scheduled_start_at: :asc)
    when "status"
      @appointments = @appointments.order(status: :asc)
    else
      @appointments = @appointments.order(created_at: :desc)
    end

    # Pagination
    @pagy, @appointments = pagy(@appointments, items: 20)
  end

  def show; end

  def edit; end

  def update
    if @appointment.update(appointment_params)
      redirect_to admin_appointment_path(@appointment), notice: "Appointment updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @appointment.discard
      redirect_to admin_appointments_path, notice: "Appointment deleted successfully."
    else
      redirect_to admin_appointment_path(@appointment), alert: "Failed to delete appointment."
    end
  end

  private

  def set_appointment
    @appointment = Appointment.kept.find(params[:id])
  end

  def load_filter_options
    @organizations = Organization.kept.order(:name)
    @providers = Provider.kept.active.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
    @statuses = Appointment.statuses.keys
    @appointment_types = Appointment.appointment_types.keys
    @show_time_filter = true if action_name == "index"
  end

  def appointment_params
    params.require(:appointment).permit(
      :organization_id,
      :organization_location_id,
      :provider_id,
      :patient_id,
      :specialty_id,
      :appointment_type,
      :status,
      :scheduled_start_at,
      :scheduled_end_at,
      :actual_start_at,
      :actual_end_at,
      :reason_for_visit,
      :notes
    )
  end
end
