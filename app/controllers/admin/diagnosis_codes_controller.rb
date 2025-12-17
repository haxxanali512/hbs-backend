class Admin::DiagnosisCodesController < Admin::BaseController
  before_action :set_diagnosis_code, only: [ :show, :edit, :update, :destroy, :retire, :activate ]

  def index
    @diagnosis_codes = DiagnosisCode.order(:code)
    @diagnosis_codes = @diagnosis_codes.search(params[:search]) if params[:search].present?
    status_param = params[:status] || params[:action_type]
    @diagnosis_codes = @diagnosis_codes.where(status: status_param) if status_param.present?
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

  def new
    @diagnosis_code = DiagnosisCode.new(status: :active)
  end

  def create
    @diagnosis_code = DiagnosisCode.new(diagnosis_code_params)
    if @diagnosis_code.save
      redirect_to admin_diagnosis_code_path(@diagnosis_code), notice: "Diagnosis code created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @diagnosis_code.update(diagnosis_code_params)
      redirect_to admin_diagnosis_code_path(@diagnosis_code), notice: "Diagnosis code updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @diagnosis_code.destroy
      redirect_to admin_diagnosis_codes_path, notice: "Diagnosis code deleted."
    else
      redirect_to admin_diagnosis_code_path(@diagnosis_code), alert: "Failed to delete diagnosis code."
    end
  end

  def retire
    if @diagnosis_code.may_retire? && @diagnosis_code.retire!
      redirect_to admin_diagnosis_code_path(@diagnosis_code), notice: "Diagnosis code retired."
    else
      redirect_to admin_diagnosis_code_path(@diagnosis_code), alert: (@diagnosis_code.errors.full_messages.join(", ").presence || "Cannot retire code.")
    end
  end

  def activate
    if @diagnosis_code.may_activate? && @diagnosis_code.activate!
      redirect_to admin_diagnosis_code_path(@diagnosis_code), notice: "Diagnosis code activated."
    else
      redirect_to admin_diagnosis_code_path(@diagnosis_code), alert: (@diagnosis_code.errors.full_messages.join(", ").presence || "Cannot activate code.")
    end
  end

  private

  def set_diagnosis_code
    @diagnosis_code = DiagnosisCode.find(params[:id])
  end

  def diagnosis_code_params
    params.require(:diagnosis_code).permit(:code, :description, :status, :effective_from, :effective_to)
  end
end
