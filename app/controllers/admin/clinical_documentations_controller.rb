class Admin::ClinicalDocumentationsController < Admin::BaseController
  before_action :set_clinical_documentation, only: [ :show, :download ]

  def index
    @clinical_documentations = ClinicalDocumentation
      .with_file
      .includes(:encounter, :patient, :organization, :author_provider)
      .order(created_at: :desc)

    @clinical_documentations = @clinical_documentations.for_organization(params[:organization_id]) if params[:organization_id].present?

    apply_filters
    apply_search
    apply_sort

    @pagy, @clinical_documentations = pagy(@clinical_documentations, items: 20)
    load_filter_options
  end

  def show
    unless @clinical_documentation.file.attached?
      redirect_to admin_clinical_documentations_path, alert: "Document file not found."
      return
    end
    redirect_to rails_blob_path(@clinical_documentation.file, disposition: "inline")
  end

  def download
    unless @clinical_documentation.file.attached?
      redirect_to admin_clinical_documentations_path, alert: "Document file not found."
      return
    end
    redirect_to rails_blob_path(@clinical_documentation.file, disposition: "attachment")
  end

  private

  def set_clinical_documentation
    @clinical_documentation = ClinicalDocumentation.with_file.find(params[:id])
  end

  def apply_filters
    @clinical_documentations = @clinical_documentations.where(patient_id: params[:patient_id]) if params[:patient_id].present?
    @clinical_documentations = @clinical_documentations.where(source_type: params[:source_type]) if params[:source_type].present?
    @clinical_documentations = @clinical_documentations.where(author_provider_id: params[:provider_id]) if params[:provider_id].present?

    if params[:date_from].present?
      @clinical_documentations = @clinical_documentations.joins(:encounter).where("encounters.date_of_service >= ?", params[:date_from])
    end
    if params[:date_to].present?
      @clinical_documentations = @clinical_documentations.joins(:encounter).where("encounters.date_of_service <= ?", params[:date_to])
    end
    if params[:uploaded_from].present?
      @clinical_documentations = @clinical_documentations.where("clinical_documentations.created_at >= ?", params[:uploaded_from])
    end
    if params[:uploaded_to].present?
      @clinical_documentations = @clinical_documentations.where("clinical_documentations.created_at <= ?", Time.zone.parse(params[:uploaded_to]).end_of_day)
    end
    if params[:specialty_id].present?
      @clinical_documentations = @clinical_documentations.joins(encounter: :specialty).where(encounters: { specialty_id: params[:specialty_id] })
    end
  end

  def apply_search
    return if params[:search].blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].strip)}%"
    @clinical_documentations = @clinical_documentations
      .left_joins(:patient, :author_provider, :encounter)
      .left_joins(file_attachment: :blob)
      .where(
        "patients.first_name ILIKE :q OR patients.last_name ILIKE :q OR providers.first_name ILIKE :q OR providers.last_name ILIKE :q OR encounters.id::text ILIKE :q OR active_storage_blobs.filename ILIKE :q",
        q: q
      )
      .references(:patient, :author_provider, :encounter)
  end

  def apply_sort
    case params[:sort]
    when "uploaded_asc"
      @clinical_documentations = @clinical_documentations.reorder("clinical_documentations.created_at ASC")
    when "uploaded_desc"
      @clinical_documentations = @clinical_documentations.reorder("clinical_documentations.created_at DESC")
    when "dos_asc"
      @clinical_documentations = @clinical_documentations.joins(:encounter).reorder("encounters.date_of_service ASC")
    when "dos_desc"
      @clinical_documentations = @clinical_documentations.joins(:encounter).reorder("encounters.date_of_service DESC")
    else
      @clinical_documentations = @clinical_documentations.reorder("clinical_documentations.created_at DESC")
    end
  end

  def load_filter_options
    @organizations = Organization.order(:name)
    @patients = Patient.kept.order(:first_name, :last_name).limit(500)
    @patients = @patients.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    @providers = Provider.kept.active.order(:last_name, :first_name)
    @specialties = Specialty.active.kept.order(:name)
    @source_type_options = ClinicalDocumentation.source_types.keys
  end
end
