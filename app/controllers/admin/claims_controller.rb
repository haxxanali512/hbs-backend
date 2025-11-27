class Admin::ClaimsController < Admin::BaseController
  include Admin::Concerns::ClaimSubmission

  before_action :set_claim, only: [ :show, :edit, :update, :destroy, :validate, :submit, :test_ezclaim_connection, :claim_insured_data, :submit_claim_insured, :post_adjudication, :void, :reverse, :close ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]

  def index
    @claims = build_claims_index_query
    @claims = apply_claims_filters(@claims)
    @claims = apply_claims_sorting(@claims)
    @pagy, @claims = paginate_claims(@claims)
  end

  def show; end

  def new
    @claim = Claim.new
    @encounter = Encounter.find(params[:encounter_id]) if params[:encounter_id].present?
    if @encounter
      @claim.organization_id = @encounter.organization_id
      @claim.encounter_id = @encounter.id
      @claim.patient_id = @encounter.patient_id
      @claim.provider_id = @encounter.provider_id
      @claim.specialty_id = @encounter.specialty_id
      @claim.place_of_service_code = @encounter.organization_location&.place_of_service_code || "11"
    end
  end

  def create
    @claim = Claim.new(claim_params)
    @encounter = @claim.encounter if @claim.encounter_id.present?

    if @claim.save
      redirect_to admin_claim_path(@claim), notice: "Claim created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @claim.update(claim_params)
      redirect_to admin_claim_path(@claim), notice: "Claim updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @claim.destroy
      redirect_to admin_claims_path, notice: "Claim deleted successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Failed to delete claim."
    end
  end

  def validate
    if @claim.valid?
      @claim.update(status: :validated) unless @claim.validated?
      redirect_to admin_claim_path(@claim), notice: "Claim validated successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Claim validation failed: #{@claim.errors.full_messages.join(', ')}"
    end
  end

  def submit
    return if validate_claim_submission_status
    return if validate_ezclaim_enabled

    begin
      ActiveRecord::Base.transaction do
        apply_internal_submission_changes
        submit_to_ezclaim
      end

      render_submission_success
    rescue EzclaimService::AuthenticationError, EzclaimService::IntegrationError => e
      handle_ezclaim_error(e)
    rescue => e
      handle_submission_error(e)
    end
  end

  def test_ezclaim_connection
    service = EzclaimService.new(organization: @claim.organization)

    # Test connection
    connection_result = service.test_connection

    if connection_result[:success]
      # Get API config
      config = service.api_config

      # Build payload preview
      payload = build_ezclaim_payload_preview

      render json: {
        success: true,
        api_url: config[:api_url],
        api_version: config[:api_version],
        payload: payload
      }
    else
      render json: {
        success: false,
        error: connection_result[:message] || connection_result[:error] || "Connection test failed"
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("EZclaim connection test error: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def claim_insured_data
    payload = build_claim_insured_payload
    config = EzclaimService.new(organization: @claim.organization).api_config

    render json: {
      success: true,
      api_url: config[:api_url],
      api_version: config[:api_version],
      payload: payload
    }
  rescue => e
    Rails.logger.error("Claim insured data error: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def submit_claim_insured
    return if validate_ezclaim_enabled

    begin
      payload = claim_insured_params.to_h
      service = EzclaimService.new(organization: @claim.organization)
      result = service.create_claim_insured(payload)

      if result[:success]
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), notice: "Claim insured submitted to EZClaim successfully." }
          format.json { render json: { success: true, redirect_url: admin_claim_path(@claim) } }
        end
      else
        respond_to do |format|
          format.html { redirect_to admin_claim_path(@claim), alert: "Failed to submit claim insured: #{result[:error]}" }
          format.json { render json: { success: false, error: result[:error] }, status: :unprocessable_entity }
        end
      end
    rescue EzclaimService::AuthenticationError, EzclaimService::IntegrationError => e
      respond_to do |format|
        format.html { redirect_to admin_claim_path(@claim), alert: "EZClaim error: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    rescue => e
      Rails.logger.error("Claim insured submission error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      respond_to do |format|
        format.html { redirect_to admin_claim_path(@claim), alert: "Error submitting claim insured: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def post_adjudication
    # Placeholder for ERA/EOB posting logic
    redirect_to admin_claim_path(@claim), notice: "Adjudication posting (placeholder)."
  end

  def void
    if @claim.can_be_voided?
      @claim.update!(status: :voided, finalized_at: Time.current)
      redirect_to admin_claim_path(@claim), notice: "Claim voided successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Claim cannot be voided."
    end
  end

  def reverse
    if @claim.can_be_reversed?
      @claim.update!(status: :reversed, finalized_at: Time.current)
      redirect_to admin_claim_path(@claim), notice: "Claim reversed successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Claim cannot be reversed."
    end
  end

  def close
    if @claim.can_be_closed?
      @claim.update!(status: :closed, finalized_at: Time.current)
      redirect_to admin_claim_path(@claim), notice: "Claim closed successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Claim cannot be closed."
    end
  end

  private

  def set_claim
    @claim = Claim.find(params[:id])
  end

  def build_ezclaim_payload_preview
    {
      claim_id: @claim.id,
      organization_id: @claim.organization.id,
      patient: {
        first_name: @claim.patient.first_name,
        last_name: @claim.patient.last_name,
        dob: @claim.patient.dob&.strftime("%Y-%m-%d"),
        mrn: @claim.patient.mrn
      },
      provider: {
        npi: @claim.provider.npi,
        name: @claim.provider.full_name
      },
      date_of_service: @claim.encounter.date_of_service.strftime("%Y-%m-%d"),
      place_of_service: @claim.place_of_service_code,
      diagnosis_codes: @claim.encounter.diagnosis_codes.map(&:code),
      claim_lines: @claim.claim_lines.map do |line|
        {
          procedure_code: line.procedure_code.code,
          description: line.procedure_code.description,
          units: line.units,
          amount_billed: line.amount_billed,
          modifiers: line.modifiers,
          diagnosis_pointers: line.dx_pointers_numeric
        }
      end,
      total_billed: @claim.total_billed,
      total_units: @claim.total_units
    }
  end

  def build_claim_insured_payload
    patient = @claim.patient
    coverage = @claim.patient_insurance_coverage

    {
      ClaInsFirstName: patient.first_name,
      ClaInsLastName: patient.last_name,
      ClaInsBirthDate: patient.dob&.strftime("%Y-%m-%d"),
      ClaInsSex: patient.sex_at_birth&.upcase,
      ClaInsAddress1: patient.address_line_1,
      ClaInsCity: patient.city,
      ClaInsState: patient.state,
      ClaInsZip: patient.postal,
      ClaInsPhone: patient.phone_number,
      ClaInsEmployer: "",
      ClaInsCompanyName: coverage&.insurance_plan&.payer&.name || "",
      ClaInsInsuranceID: coverage&.member_id || "",
      ClaInsGroupNumber: "",
      ClaInsPlanName: coverage&.insurance_plan&.name || "",
      ClaInsRelationToInsured: map_relationship_to_insured(coverage&.relationship_to_subscriber),
      ClaInsSequence: map_coverage_order(coverage&.coverage_order),
      ClaInsAcceptAssignment: "",
      ClaInsFilingIndicator: "",
      ClaInsSSN: "",
      ClaInsClaFID: @claim.external_claim_key || @claim.id.to_s,
      ClaInsPatFID: patient.external_id || patient.id.to_s,
      ClaInsGUID: ""
    }
  end

  def claim_insured_params
    params.require(:claim_insured).permit(
      :ClaInsFirstName,
      :ClaInsLastName,
      :ClaInsBirthDate,
      :ClaInsSex,
      :ClaInsAddress1,
      :ClaInsCity,
      :ClaInsState,
      :ClaInsZip,
      :ClaInsPhone,
      :ClaInsEmployer,
      :ClaInsCompanyName,
      :ClaInsInsuranceID,
      :ClaInsGroupNumber,
      :ClaInsPlanName,
      :ClaInsRelationToInsured,
      :ClaInsSequence,
      :ClaInsAcceptAssignment,
      :ClaInsFilingIndicator,
      :ClaInsSSN,
      :ClaInsClaFID,
      :ClaInsPatFID,
      :ClaInsGUID
    )
  end

  def map_relationship_to_insured(relationship)
    case relationship&.to_s
    when "self" then "S"
    when "spouse" then "S"
    when "child" then "C"
    when "other" then "O"
    else "S"
    end
  end

  def map_coverage_order(order)
    case order&.to_s
    when "primary" then "1"
    when "secondary" then "2"
    when "tertiary" then "3"
    else "1"
    end
  end

  def load_form_options
    @organizations = Organization.kept.order(:name)
    @providers = Provider.kept.active.order(:first_name, :last_name)
    @patients = Patient.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
    @encounters = Encounter.kept.order(date_of_service: :desc).limit(100)
    @procedure_codes = ProcedureCode.active.order(:code)
    @statuses = Claim.statuses.keys

    if action_name == "index"
      @statuses = Claim.statuses.keys
    end
  end

  def claim_params
    permitted = params.require(:claim).permit(
      :organization_id,
      :encounter_id,
      :patient_id,
      :provider_id,
      :specialty_id,
      :place_of_service_code,
      :status,
      :external_claim_key,
      claim_lines_attributes: [
        :id,
        :procedure_code_id,
        :units,
        :amount_billed,
        :place_of_service_code,
        :modifiers,
        :dx_pointers_numeric,
        :_destroy
      ]
    )

    # Convert modifiers and dx_pointers_numeric from comma-separated strings to arrays
    attrs = permitted[:claim_lines_attributes]
    if attrs.present?
      if attrs.is_a?(Array)
        attrs.each { |line_attrs| normalize_line_attrs!(line_attrs) }
      else
        # Hash of index => attrs
        attrs.each do |_, line_attrs|
          normalize_line_attrs!(line_attrs)
        end
      end
    end

    permitted
  end

  def normalize_line_attrs!(line_attrs)
    return if line_attrs.nil?

    # Modifiers can come as a comma-separated string or array
    if line_attrs[:modifiers].present? && !line_attrs[:modifiers].is_a?(Array)
      line_attrs[:modifiers] = line_attrs[:modifiers].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    # dx_pointers_numeric can come as a comma-separated string or array of strings/ints
    if line_attrs[:dx_pointers_numeric].present? && !line_attrs[:dx_pointers_numeric].is_a?(Array)
      line_attrs[:dx_pointers_numeric] = line_attrs[:dx_pointers_numeric].to_s.split(",")
    end
    if line_attrs[:dx_pointers_numeric].is_a?(Array)
      line_attrs[:dx_pointers_numeric] = line_attrs[:dx_pointers_numeric].map { |v| v.to_s.strip }.reject(&:blank?).map(&:to_i)
    end
  end
end
