class Tenant::EligibilityChecksController < Tenant::BaseController
  before_action :set_current_organization
  before_action :load_form_options, only: [ :index ]

  def index
  end

  def status
    check_id = params[:check_id].presence
    unless check_id
      return render json: { error: "check_id required" }, status: :bad_request
    end
    result = FuseApiService.new.get_check(check_id: check_id)
    render json: {
      completed: result["completed"] == true,
      status: result["status"],
      check_result: result["completed"] == true ? result : nil
    }
  rescue FuseApiService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def result
    check_id = params[:check_id].presence
    unless check_id
      return head :bad_request
    end
    check_result = FuseApiService.new.get_check(check_id: check_id)
    render partial: "tenant/eligibility_checks/result", locals: { check_result: check_result }, layout: false
  rescue FuseApiService::Error
    render partial: "tenant/eligibility_checks/result_error", locals: { message: "Could not load result." }, layout: false
  end

  def create
    result = FuseEligibilityCheckFromParamsService.submit(
      organization: @current_organization,
      user: current_user,
      params: eligibility_check_params,
      poll: false
    )
    check_id = result[:check_id]
    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.remove("eligibility-loader"),
          turbo_stream.append("eligibility_results", partial: "tenant/eligibility_checks/pending", locals: { check_id: check_id })
        ]
        render turbo_stream: streams
      end
      format.html { redirect_to tenant_eligibility_checks_path, notice: "Eligibility check submitted." }
    end
  rescue FuseEligibilityCheckFromParamsService::Error, FuseApiService::Error => e
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("eligibility-loader"),
          turbo_stream.append("eligibility_results", partial: "tenant/eligibility_checks/result_error", locals: { message: e.message })
        ]
      end
      format.html { redirect_to tenant_eligibility_checks_path, alert: "Eligibility check failed: #{e.message}" }
    end
  end

  private

  def load_form_options
    @payers = Payer.active_only.order(:name)
    @providers = @current_organization.providers.kept.active.order(:first_name, :last_name)
    @procedure_codes = ProcedureCode.active.kept.order(:code).limit(500)
    loc = @current_organization.organization_locations.billing.active.first
    @default_billing_address = loc ? [ loc.address_line_1, loc.address_line_2, loc.city, loc.state, loc.postal_code ].compact_blank.join(", ") : ""
    ident = @current_organization.organization_identifier
    @default_tax_id = ident&.tax_identification_number.to_s
  end

  def eligibility_check_params
    params.permit(
      :check_id,
      :patient_first_name, :patient_last_name, :patient_date_of_birth, :patient_relationship,
      :subscriber_member_id, :subscriber_first_name, :subscriber_last_name, :subscriber_date_of_birth,
      :payer_id, :provider_id, :place_of_service_code,
      :provider_billing_address, :provider_tax_id, :provider_is_specialist,
      procedure_code_ids: []
    )
  end
end
