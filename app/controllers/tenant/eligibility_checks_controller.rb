class Tenant::EligibilityChecksController < Tenant::BaseController
  before_action :set_current_organization
  before_action :load_form_options, only: [ :index ]

  def index
  end

  def create
    result = FuseEligibilityCheckFromParamsService.submit(
      organization: @current_organization,
      user: current_user,
      params: eligibility_check_params
    )
    @check_result = result[:check_result]
    respond_to do |format|
      format.turbo_stream do
        streams = [ turbo_stream.remove("eligibility-loader") ]
        if @check_result.present?
          streams << turbo_stream.append("eligibility_results", partial: "tenant/eligibility_checks/result", locals: { check_result: @check_result })
        else
          streams << turbo_stream.append("eligibility_results", partial: "tenant/eligibility_checks/result", locals: { check_result: { "checkId" => result[:check_id], "completed" => false, "createdAt" => nil, "updatedAt" => nil, "results" => nil } })
        end
        render turbo_stream: streams
      end
      format.html { redirect_to tenant_eligibility_checks_path, notice: "Eligibility check completed." }
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
  end

  def eligibility_check_params
    params.permit(
      :check_id,
      :patient_first_name, :patient_last_name, :patient_date_of_birth, :patient_relationship,
      :subscriber_member_id, :subscriber_first_name, :subscriber_last_name, :subscriber_date_of_birth,
      :payer_id, :provider_id, :place_of_service_code,
      procedure_code_ids: []
    )
  end
end
