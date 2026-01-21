class Admin::EncounterTemplatesController < Admin::BaseController
  before_action :set_encounter_template, only: [ :show, :edit, :update, :destroy ]
  before_action :load_form_options, only: [ :new, :edit, :create, :update ]

  def index
    @encounter_templates = EncounterTemplate.includes(:specialty)
                                            .order(:name)

    @search_placeholder = "Template name..."
    @status_options = [ [ "Active", "active" ], [ "Inactive", "inactive" ] ]
    @specialty_options = Specialty.kept.active.order(:name)

    if params[:search].present?
      @encounter_templates = @encounter_templates.where("encounter_templates.name ILIKE ?", "%#{params[:search]}%")
    end

    if params[:specialty_id].present?
      @encounter_templates = @encounter_templates.where(specialty_id: params[:specialty_id])
    end

    if params[:status].present?
      active_value =
        case params[:status]
        when "active" then true
        when "inactive" then false
        end
      @encounter_templates = @encounter_templates.where(active: active_value) unless active_value.nil?
    end

    @pagy, @encounter_templates = pagy(@encounter_templates, items: 20)
  end

  def show; end

  def new
    @encounter_template = EncounterTemplate.new(active: true)
    @encounter_template.encounter_template_lines.build(units: 1)
  end

  def create
    @encounter_template = EncounterTemplate.new(encounter_template_params)
    if @encounter_template.save
      redirect_to admin_encounter_template_path(@encounter_template), notice: "Encounter template created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @encounter_template.encounter_template_lines.build(units: 1) if @encounter_template.encounter_template_lines.empty?
  end

  def update
    if @encounter_template.update(encounter_template_params)
      redirect_to admin_encounter_template_path(@encounter_template), notice: "Encounter template updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @encounter_template.destroy
    redirect_to admin_encounter_templates_path, notice: "Encounter template deleted."
  end

  private

  def set_encounter_template
    @encounter_template = EncounterTemplate.find(params[:id])
  end

  def load_form_options
    @specialties = Specialty.kept.active.order(:name)
    @procedure_codes = ProcedureCode.kept.active.order(:code)
  end

  def encounter_template_params
    params.require(:encounter_template).permit(
      :name,
      :specialty_id,
      :active,
      encounter_template_lines_attributes: [
        :id,
        :procedure_code_id,
        :units,
        :modifiers_text,
        :_destroy
      ]
    )
  end
end
