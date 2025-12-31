class Admin::ClaimsController < Admin::BaseController
  include Admin::Concerns::ClaimSubmission

  before_action :set_claim, only: [ :show, :edit, :update, :destroy, :validate, :submit, :test_ezclaim_connection, :post_adjudication, :void, :reverse, :close, :download_edi ]
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

      render json: {
        success: true,
        api_url: config[:api_url],
        api_version: config[:api_version],
        message: "Connection successful"
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

  def download_edi
    unless @claim.edi_file&.attached?
      redirect_to admin_claim_path(@claim), alert: "EDI file not found for this claim."
      return
    end

    redirect_to rails_blob_path(@claim.edi_file, disposition: "attachment")
  end

  private

  def set_claim
    @claim = Claim.find(params[:id])
  end


  def load_form_options
    @organizations = Organization.kept.order(:name)
    @providers = Provider.kept.active.order(:first_name, :last_name)
    @patients = Patient.order(:first_name, :last_name)
    @specialties = Specialty.active.kept.order(:name)
    @encounters = Encounter.kept.order(date_of_service: :desc).limit(100)
    @procedure_codes = resolve_procedure_codes_for_selected_org
    @statuses = Claim.statuses.keys

    if action_name == "index"
      @statuses = Claim.statuses.keys
    end
  end

  def resolve_procedure_codes_for_selected_org
    org_id = params.dig(:claim, :organization_id) || params[:organization_id] || @claim&.organization_id
    if org_id.present?
      org = Organization.find_by(id: org_id)
      return org.unlocked_procedure_codes.kept.active.order(:code) if org
    end

    # Fallback to all active codes if no org selected
    ProcedureCode.active.order(:code)
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
