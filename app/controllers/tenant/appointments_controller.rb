class Tenant::AppointmentsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_appointment, only: [ :show, :edit, :update, :destroy, :cancel, :complete, :mark_no_show ]
  before_action :load_form_options, only: [ :index, :new, :create, :edit, :update ]

  def index
    @appointments = @current_organization.appointments.includes(:patient, :provider, :specialty, :organization_location).kept

    # Filtering
    @appointments = @appointments.by_status(params[:status]) if params[:status].present?
    @appointments = @appointments.by_provider(params[:provider_id]) if params[:provider_id].present?
    @appointments = @appointments.by_patient(params[:patient_id]) if params[:patient_id].present?
    @appointments = @appointments.by_specialty(params[:specialty_id]) if params[:specialty_id].present?
    @appointments = @appointments.by_location(params[:location_id]) if params[:location_id].present?

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
      @appointments = @appointments.order(scheduled_start_at: :asc)
    end

    # Pagination
    @pagy, @appointments = pagy(@appointments, items: 20)
  end

  def show; end

  def new
    @appointment = @current_organization.appointments.build
    @appointment.scheduled_start_at = Time.current.beginning_of_hour + 1.hour
    @appointment.scheduled_end_at = @appointment.scheduled_start_at + 30.minutes
  end

  def create
    @appointment = @current_organization.appointments.build(appointment_params)

    if @appointment.save
      redirect_to tenant_appointment_path(@appointment), notice: "Appointment created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @appointment.update(appointment_params)
      redirect_to tenant_appointment_path(@appointment), notice: "Appointment updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @appointment.discard
      redirect_to tenant_appointments_path, notice: "Appointment deleted successfully."
    else
      redirect_to tenant_appointment_path(@appointment), alert: "Failed to delete appointment."
    end
  end

  def cancel
    if @appointment.cancelled!
      redirect_to tenant_appointment_path(@appointment), notice: "Appointment cancelled successfully."
    else
      redirect_to tenant_appointment_path(@appointment), alert: "Failed to cancel appointment."
    end
  end

  def complete
    @appointment.update(actual_end_at: Time.current, status: :completed)
    redirect_to tenant_appointment_path(@appointment), notice: "Appointment completed successfully."
  end

  def mark_no_show
    if @appointment.update(status: :no_show)
      redirect_to tenant_appointment_path(@appointment), notice: "Appointment marked as no-show."
    else
      redirect_to tenant_appointment_path(@appointment), alert: "Failed to mark appointment as no-show."
    end
  end

  private

  def set_appointment
    @appointment = @current_organization.appointments.kept.find(params[:id])
  end

  def load_form_options
    @providers = @current_organization.providers.kept.active.order(:first_name, :last_name)
    @patients = @current_organization.patients.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)

    if action_name == "index"
      # For index: show all locations (kept) and add filter options
      @locations = @current_organization.organization_locations.kept.order(:name)
      @statuses = Appointment.statuses.keys
      @appointment_types = Appointment.appointment_types.keys
      @show_time_filter = true
    else
      # For forms: show only active locations
      @locations = @current_organization.organization_locations.active.order(:name)
    end
  end

  def appointment_params
    params.require(:appointment).permit(
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
