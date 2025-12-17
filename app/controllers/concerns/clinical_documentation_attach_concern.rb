module ClinicalDocumentationAttachConcern
  extend ActiveSupport::Concern

  def attach_clinical_documentation
    # Validate PDF file
    file = params.dig(:document, :file)
    unless file&.content_type == "application/pdf"
      redirect_to encounter_show_path, alert: "Only PDF files are allowed."
      return
    end

    # Create ClinicalDocumentation record first
    @clinical_documentation = @encounter.clinical_documentations.build(
      organization: @encounter.organization,
      patient: @encounter.patient,
      author_provider: @encounter.provider,
      document_type: params.dig(:clinical_documentation, :document_type) || "other",
      content_json: {
        "source" => "attached_document",
        "file_name" => file.original_filename,
        "uploaded_at" => Time.current.iso8601
      },
      version_seq: @encounter.clinical_documentations.maximum(:version_seq).to_i + 1,
      status: :signed, # Attached documents are considered signed
      signed_at: Time.current,
      signed_by_provider: @encounter.provider
    )

    unless @clinical_documentation.save
      redirect_to encounter_show_path, alert: "Error: #{@clinical_documentation.errors.full_messages.join(', ')}"
      return
    end

    # Upload document using DocumentUploadService with ClinicalDocumentation as documentable
    result = DocumentUploadService.new(
      documentable: @clinical_documentation,
      uploaded_by: current_user,
      organization: @encounter.organization,
      params: {
        file: file,
        title: params.dig(:document, :title) || "Clinical Documentation - #{@encounter.patient.full_name}",
        document_type: "clinical_documentation",
        description: params.dig(:document, :description)
      }
    ).call

    unless result[:success]
      @clinical_documentation.destroy # Clean up if upload fails
      redirect_to encounter_show_path, alert: "Failed to upload document: #{result[:error]}"
      return
    end

    redirect_to encounter_show_path, notice: "Document attached successfully as clinical documentation."
  end

  private

  def encounter_show_path
    # This will be overridden in the including controller
    raise NotImplementedError, "Subclass must implement encounter_show_path"
  end
end
