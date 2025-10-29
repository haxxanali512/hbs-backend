class Tenant::DiagnosisCodesController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_diagnosis_code, only: [ :show, :request ]

  def index
    @diagnosis_codes = DiagnosisCode.active.order(:code)
    @diagnosis_codes = @diagnosis_codes.search(params[:search]) if params[:search].present?
  end

  def show; end

  # Allows clients to request a new diagnosis code to be added
  def request
    # Placeholder: create a task/ticket for HBS to review
    # In v1, simply flash a notice
    redirect_to tenant_diagnosis_code_path(@diagnosis_code), notice: "Request submitted for review by HBS."
  end

  private

  def set_diagnosis_code
    @diagnosis_code = DiagnosisCode.find(params[:id])
  end
end
