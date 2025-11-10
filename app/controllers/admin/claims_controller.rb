class Admin::ClaimsController < Admin::BaseController
  before_action :set_claim, only: [ :show, :edit, :update, :destroy, :validate, :submit, :push_to_ezclaim, :post_adjudication, :void, :reverse, :close ]
  before_action :load_form_options, only: [ :index, :new, :edit, :create, :update ]

  def index
    @claims = Claim.includes(:organization, :encounter, :patient, :provider, :specialty, :claim_lines)

    # Filtering by organization
    @claims = @claims.where(organization_id: params[:organization_id]) if params[:organization_id].present?

    # Filtering by status
    @claims = @claims.where(status: params[:status]) if params[:status].present?

    # Filtering by provider
    @claims = @claims.where(provider_id: params[:provider_id]) if params[:provider_id].present?

    # Filtering by patient
    @claims = @claims.where(patient_id: params[:patient_id]) if params[:patient_id].present?

    # Filtering by specialty
    @claims = @claims.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?

    # Date range filter
    if params[:date_from].present? && params[:date_to].present?
      @claims = @claims.joins(:encounter).where(
        "encounters.date_of_service >= ? AND encounters.date_of_service <= ?",
        params[:date_from],
        params[:date_to]
      )
    elsif params[:date_from].present?
      @claims = @claims.joins(:encounter).where("encounters.date_of_service >= ?", params[:date_from])
    elsif params[:date_to].present?
      @claims = @claims.joins(:encounter).where("encounters.date_of_service <= ?", params[:date_to])
    end

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @claims = @claims.joins(:patient)
        .where("patients.first_name ILIKE ? OR patients.last_name ILIKE ?", search_term, search_term)
    end

    # Sorting
    case params[:sort]
    when "date_desc"
      @claims = @claims.joins(:encounter).order("encounters.date_of_service DESC")
    when "date_asc"
      @claims = @claims.joins(:encounter).order("encounters.date_of_service ASC")
    when "status"
      @claims = @claims.order(status: :asc)
    when "total_billed_desc"
      @claims = @claims.order(total_billed: :desc)
    else
      @claims = @claims.order(created_at: :desc)
    end

    # Pagination
    @pagy, @claims = pagy(@claims, items: 20)
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
    if @claim.generated? || @claim.validated?
      ActiveRecord::Base.transaction do
        @claim.update!(status: :submitted)
        @claim.claim_lines.update_all(status: "locked_on_submission")
        @claim.update!(submitted_at: Time.current)

        # Create a submission attempt record
        # TODO: Implement GEN API call to create submission key
        @claim.claim_submissions.create!(
          submission_method: :api,
          status: :submitted,
          ack_status: :pending,
          submitted_at: Time.current,
          external_submission_key: SecureRandom.uuid # placeholder until GEN returns a real key
        )
      end
      redirect_to admin_claim_path(@claim), notice: "Claim submitted successfully."
    else
      redirect_to admin_claim_path(@claim), alert: "Claim cannot be submitted from current status."
    end
  end

  def push_to_ezclaim
    result = EzclaimIntegrationService.new(
      claim: @claim,
      organization: @claim.organization
    ).push_claim

    if result[:success]
      redirect_to admin_claim_path(@claim), notice: "Claim pushed to EZclaim successfully. #{result[:message]}"
    else
      redirect_to admin_claim_path(@claim), alert: "Failed to push to EZclaim: #{result[:error]}"
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
