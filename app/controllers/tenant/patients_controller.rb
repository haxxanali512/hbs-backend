class Tenant::PatientsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_patient, only: [ :show, :edit, :update, :destroy, :activate, :inactivate, :mark_deceased, :reactivate, :push_to_ezclaim, :check_eligibility ]

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
    when "dob_asc"
      @patients = @patients.order(:dob)
    when "dob_desc"
      @patients = @patients.order(dob: :desc)
    when "created_desc"
      @patients = @patients.order(created_at: :desc)
    when "created_asc"
      @patients = @patients.order(:created_at)
    when "mrn_asc"
      @patients = @patients.order(:mrn)
    when "mrn_desc"
      @patients = @patients.order(mrn: :desc)
    else
      @patients = @patients.recent
    end

    # Pagination
    @pagy, @patients = pagy(@patients, items: 20)

    # For filters
    @statuses = Patient.statuses.keys
    @sort_options = [
      [ "Recently Added", "created_desc" ],
      [ "Oldest First", "created_asc" ],
      [ "Name (A-Z)", "name_asc" ],
      [ "Name (Z-A)", "name_desc" ],
      [ "Date of Birth (Oldest)", "dob_asc" ],
      [ "Date of Birth (Youngest)", "dob_desc" ],
      [ "MRN (A-Z)", "mrn_asc" ],
      [ "MRN (Z-A)", "mrn_desc" ]
    ]
  end

  def show
    # Eager load insurance coverages to avoid N+1 queries
    @patient.patient_insurance_coverages.load
    # Encounters with insurance (for manual eligibility check)
    @eligibility_encounters = @patient.encounters.kept
      .where.not(patient_insurance_coverage_id: nil)
      .includes(:provider, :specialty, :organization)
      .includes(patient_insurance_coverage: :insurance_plan)
      .order(date_of_service: :desc)
      .limit(20)
  end

  def new
    @patient = @current_organization.patients.build
    if @patient.patient_insurance_coverages.empty?
      @patient.patient_insurance_coverages.build(
        status: :draft,
        coverage_order: :primary,
        organization_id: @current_organization.id
      )
    end
    load_insurance_form_options
  end

  def create
    @patient = @current_organization.patients.build(patient_params)
    set_insurance_coverage_organization_ids

    if @patient.save
      redirect_to tenant_patient_path(@patient, add_prescription: true), notice: "Patient created successfully."
    else
      load_insurance_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    if @patient.patient_insurance_coverages.empty?
      @patient.patient_insurance_coverages.build(
        status: :draft,
        coverage_order: :primary,
        organization_id: @current_organization.id
      )
    end
    load_insurance_form_options
  end

  def update
    @patient.assign_attributes(patient_params)
    set_insurance_coverage_organization_ids

    if @patient.save
      redirect_to tenant_patient_path(@patient), notice: "Patient updated successfully."
    else
      load_insurance_form_options
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

  def check_eligibility
    encounter = @current_organization.encounters.kept.find_by(id: params[:encounter_id], patient_id: @patient.id)
    unless encounter
      redirect_to tenant_patient_path(@patient), alert: "Encounter not found or does not belong to this patient."
      return
    end
    unless encounter.patient_insurance_coverage_id.present?
      redirect_to tenant_patient_path(@patient), alert: "This encounter has no insurance coverage. Select an insurance coverage on the encounter to check eligibility."
      return
    end
    payer = encounter.patient_insurance_coverage&.insurance_plan&.payer
    check_id = payer.present? ? "payer-#{payer.id}-#{encounter.id}" : nil

    result = FuseEligibilitySubmitService.submit(encounter: encounter, check_id: check_id)
    redirect_to tenant_patient_path(@patient),
                notice: "Eligibility check submitted. Check ID: #{result['checkId']}. You will receive results via webhook."
  rescue FuseEligibilitySubmitService::Error, FuseApiService::Error => e
    redirect_to tenant_patient_path(@patient), alert: "Eligibility check failed: #{e.message}"
  end

  def push_to_ezclaim
    unless @current_organization&.organization_setting&.ezclaim_enabled?
      redirect_to tenant_patient_path(@patient), alert: "EZClaim is not enabled for this organization."
      return
    end

    begin
      service = EzclaimService.new(organization: @current_organization)

      # Map patient fields to EZClaim fields
      patient_data = {
        PatFirstName: @patient.first_name,
        PatLastName: @patient.last_name,
        PatCity: @patient.city,
        PatAddress: @patient.address_line_1,
        PatZip: @patient.postal,
        PatBirthDate: @patient.dob&.strftime("%Y-%m-%d"),
        PatState: @patient.state,
        PatSex: @patient.sex_at_birth
      }

      result = service.create_patient(patient_data)

      if result[:success]
        redirect_to tenant_patient_path(@patient), notice: "Patient successfully pushed to EZClaim."
      else
        redirect_to tenant_patient_path(@patient), alert: "Failed to push patient to EZClaim: #{result[:error]}"
      end
    rescue => e
      Rails.logger.error "Error pushing patient #{@patient.id} to EZClaim: #{e.message}"
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to tenant_patient_path(@patient), alert: "Error pushing patient to EZClaim: #{e.message}"
    end
  end

  private

  def set_patient
    @patient = @current_organization.patients.kept.find(params[:id])
  end

  def patient_params
    # Process subscriber_address fields before permitting
    process_insurance_coverage_addresses

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
      :notes_nonphi,
      :push_to_ezclaim,
      prescription_attributes: [
        :id,
        :expires_on,
        :title
      ],
      patient_insurance_coverages_attributes: [
        :id,
        :insurance_plan_id,
        :member_id,
        :subscriber_name,
        :relationship_to_subscriber,
        :coverage_order,
        :effective_date,
        :termination_date,
        :status,
        :_destroy,
        subscriber_address: {}
      ]
    )
  end


  def load_insurance_form_options
    @insurance_plans = @current_organization.eligible_insurance_plans_for_patient_coverages
  end

  def process_insurance_coverage_addresses
    return unless params.dig(:patient, :patient_insurance_coverages_attributes)

    params[:patient][:patient_insurance_coverages_attributes].each do |index, coverage_params|
      next unless coverage_params[:subscriber_address_line1].present?

      params[:patient][:patient_insurance_coverages_attributes][index][:subscriber_address] = {
        line1: coverage_params[:subscriber_address_line1],
        line2: coverage_params[:subscriber_address_line2],
        city: coverage_params[:subscriber_address_city],
        state: coverage_params[:subscriber_address_state],
        postal: coverage_params[:subscriber_address_postal],
        country: coverage_params[:subscriber_address_country] || "US"
      }
    end
  end

  def set_insurance_coverage_organization_ids
    @patient.patient_insurance_coverages.each do |coverage|
      coverage.organization_id = @current_organization.id if coverage.organization_id.blank?
    end
  end
end
