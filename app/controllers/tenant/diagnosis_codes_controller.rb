class Tenant::DiagnosisCodesController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_diagnosis_code, only: [ :show, :request_review ]

  def index
    @diagnosis_codes = DiagnosisCode.active.order(:code)
    @diagnosis_codes = @diagnosis_codes.search(params[:search]) if params[:search].present?
    @pagy, @diagnosis_codes = pagy(@diagnosis_codes, items: 20)
  end

  def show; end

  def search
    search_term = params[:q] || params[:search] || ""

    diagnosis_codes = DiagnosisCode.active
                                   .search(search_term)
                                   .limit(50)
                                   .order(:code)

    render json: {
      success: true,
      results: diagnosis_codes.map do |dc|
        {
          id: dc.id,
          code: dc.code || "",
          description: dc.description || "",
          display: "#{dc.code || 'N/A'} - #{dc.description || 'No description'}"
        }
      end
    }
  rescue => e
    Rails.logger.error("Error in diagnosis_codes search: #{e.message}")
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  # Allows clients to request a new diagnosis code to be added
  def request_review
    # Placeholder: create a task/ticket for HBS to review
    # In v1, simply flash a notice
    redirect_to tenant_diagnosis_code_path(@diagnosis_code), notice: "Request submitted for review by HBS."
  end

  private

  def set_diagnosis_code
    @diagnosis_code = DiagnosisCode.find(params[:id])
  end
end
