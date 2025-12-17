class Tenant::ClinicalDocumentationsController < Tenant::BaseController
  include ClinicalDocumentationAttachConcern

  before_action :set_encounter
  before_action :set_clinical_documentation, only: [ :edit, :update, :destroy, :sign, :cosign, :amend, :void_readonly, :export_pdf ]

  def create
    # Check if this is an attach mode (PDF upload)
    if params[:attach_mode] == "true" && params.dig(:document, :file).present?
      attach_document
      return
    end

    # Otherwise, create form-based documentation
    @clinical_documentation = @encounter.clinical_documentations.build(clinical_documentation_params)
    @clinical_documentation.organization = @encounter.organization
    @clinical_documentation.patient = @encounter.patient
    @clinical_documentation.author_provider = @encounter.provider
    @clinical_documentation.version_seq = @encounter.clinical_documentations.maximum(:version_seq).to_i + 1

    # Build content_json from sections
    if params[:section_names].present? && params[:section_contents].present?
      sections = params[:section_names].zip(params[:section_contents]).map do |name, content|
        { "name" => name, "content" => content }
      end
      @clinical_documentation.content_json = { "sections" => sections }
    elsif params[:clinical_documentation][:content_json].present?
      begin
        @clinical_documentation.content_json = JSON.parse(params[:clinical_documentation][:content_json])
      rescue JSON::ParserError => e
        @clinical_documentation.errors.add(:content_json, "Invalid JSON: #{e.message}")
        redirect_to tenant_encounter_path(@encounter), alert: "Error: Invalid JSON content"
        return
      end
    end

    if @clinical_documentation.save
      redirect_to tenant_encounter_path(@encounter), notice: "Clinical documentation created successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Error: #{@clinical_documentation.errors.full_messages.join(', ')}"
    end
  end

  def attach_document
    attach_clinical_documentation
  end

  private

  def encounter_show_path
    tenant_encounter_path(@encounter)
  end

  def update
    unless @clinical_documentation.draft?
      redirect_to tenant_encounter_path(@encounter), alert: "Only draft documentation can be edited."
      return
    end

    # Build content_json from sections
    if params[:section_names].present? && params[:section_contents].present?
      sections = params[:section_names].zip(params[:section_contents]).map do |name, content|
        { "name" => name, "content" => content }
      end
      @clinical_documentation.content_json = { "sections" => sections }
    elsif params[:clinical_documentation][:content_json].present?
      begin
        @clinical_documentation.content_json = JSON.parse(params[:clinical_documentation][:content_json])
      rescue JSON::ParserError => e
        @clinical_documentation.errors.add(:content_json, "Invalid JSON: #{e.message}")
        redirect_to tenant_encounter_path(@encounter), alert: "Error: Invalid JSON content"
        return
      end
    end

    if @clinical_documentation.update(clinical_documentation_params)
      redirect_to tenant_encounter_path(@encounter), notice: "Clinical documentation updated successfully."
    else
      redirect_to tenant_encounter_path(@encounter), alert: "Error: #{@clinical_documentation.errors.full_messages.join(', ')}"
    end
  end

  def sign
    unless @clinical_documentation.draft?
      render json: { success: false, error: "Only draft documentation can be signed." }, status: :unprocessable_entity
      return
    end

    @clinical_documentation.signed_by_provider = @clinical_documentation.author_provider

    if @clinical_documentation.sign
      @clinical_documentation.generate_signature_hash
      if @clinical_documentation.save
        render json: { success: true, message: "Documentation signed successfully." }
      else
        render json: { success: false, error: @clinical_documentation.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    else
      render json: { success: false, error: "Unable to sign documentation." }, status: :unprocessable_entity
    end
  end

  def cosign
    # TODO: Implement cosign logic
    render json: { success: false, error: "Cosign not yet implemented." }, status: :not_implemented
  end

  def amend
    # TODO: Implement amend logic
    render json: { success: false, error: "Amend not yet implemented." }, status: :not_implemented
  end

  def void_readonly
    if @clinical_documentation.void_readonly
      render json: { success: true, message: "Documentation voided." }
    else
      render json: { success: false, error: "Unable to void documentation." }, status: :unprocessable_entity
    end
  end

  def export_pdf
    unless @clinical_documentation.signed?
      redirect_to tenant_encounter_path(@encounter), alert: "Only signed documentation can be exported."
      return
    end

    pdf_document = @clinical_documentation.rendered_pdf_document
    unless pdf_document
      redirect_to tenant_encounter_path(@encounter), alert: "PDF not available."
      return
    end

    send_file pdf_document.file_path,
              type: "application/pdf",
              disposition: "attachment",
              filename: "#{@clinical_documentation.document_type}_#{@clinical_documentation.id}_v#{@clinical_documentation.version_seq}.pdf"
  end

  private

  def set_encounter
    @encounter = @current_organization.encounters.find(params[:encounter_id])
  end

  def set_clinical_documentation
    @clinical_documentation = @encounter.clinical_documentations.find(params[:id])
  end

  def clinical_documentation_params
    params.require(:clinical_documentation).permit(:document_type, :content_json, :attestation_text, :section_locks)
  end
end
