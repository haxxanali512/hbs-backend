class Admin::ProviderNotesController < Admin::BaseController
  before_action :set_encounter
  before_action :set_provider_note, only: [ :show ]

  def index
    @provider_notes = @encounter.provider_notes.includes(:provider).recent
  end

  def show; end

  private

  def set_encounter
    @encounter = Encounter.find(params[:encounter_id])
  end

  def set_provider_note
    @provider_note = @encounter.provider_notes.find(params[:id])
  end
end
