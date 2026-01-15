class Tenant::ProviderNotesController < Tenant::BaseController
  before_action :set_encounter
  before_action :set_provider_note, only: [ :show, :edit, :update, :destroy ]

  def index
    @provider_notes = @encounter.provider_notes.includes(:provider).recent
  end

  def show; end

  def new
    if @encounter.cascaded?
      flash[:alert] = "Cannot create provider notes after encounter finalization."
      redirect_to tenant_encounter_path(@encounter)
      return
    end

    @provider_note = @encounter.provider_notes.build(provider: current_provider)
  end

  def create
    if @encounter.cascaded?
      flash[:alert] = "Cannot create provider notes after encounter finalization."
      redirect_to tenant_encounter_path(@encounter)
      return
    end

    @provider_note = @encounter.provider_notes.build(provider_note_params)
    @provider_note.provider = current_provider unless @provider_note.provider_id.present?

    if @provider_note.save
      redirect_to tenant_encounter_path(@encounter), notice: "Provider note created successfully."
    else
      flash[:alert] = @provider_note.errors.full_messages.join(", ")
      redirect_to tenant_encounter_path(@encounter)
    end
  end

  def edit
  end

  def update
    if @provider_note.update(provider_note_params)
      redirect_to tenant_encounter_path(@encounter), notice: "Provider note updated successfully."
    else
      flash[:alert] = @provider_note.errors.full_messages.join(", ")
      redirect_to tenant_encounter_path(@encounter)
    end
  end

  def destroy
    if @provider_note.destroy
      redirect_to tenant_encounter_path(@encounter), notice: "Provider note deleted successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Failed to delete provider note."
    end
  end

  private

  def set_encounter
    @encounter = current_organization.encounters.find(params[:encounter_id])
  end

  def set_provider_note
    @provider_note = @encounter.provider_notes.find(params[:id])
  end

  def provider_note_params
    params.require(:provider_note).permit(:note_text)
  end

  def current_provider
    # Get provider associated with current user or encounter provider
    provider = nil # user_id association removed from Provider
    provider ||= @encounter&.provider
    provider
  end
end
