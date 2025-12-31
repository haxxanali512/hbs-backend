class DocumentUploadService
  class UploadError < StandardError; end

  def initialize(documentable:, uploaded_by:, organization:, params:)
    @documentable = documentable
    @uploaded_by = uploaded_by
    @organization = organization
    @uploaded_io = params[:file]
    @title = params[:title].presence || "Document Attachment"
    @document_type = params[:document_type].presence || "document"
    @description = params[:description]
  end

  def call
    validate_file!

    # Attach file directly using Active Storage
    documentable.documents.attach(
      io: uploaded_io,
      filename: sanitize_filename(uploaded_io.original_filename),
      content_type: uploaded_io.content_type
    )

    { success: true, attachment: documentable.documents.last }
  rescue => e
    Rails.logger.error("DocumentUploadService error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { success: false, error: e.message }
  end

  private

  attr_reader :documentable, :uploaded_by, :organization, :uploaded_io,
              :title, :document_type, :description

  def validate_file!
    raise UploadError, "No file provided" if uploaded_io.blank?
    raise UploadError, "File too large (max 25MB)" if uploaded_io.size > 25.megabytes
  end

  # Active Storage handles file storage automatically
  # No need for manual S3 or local storage logic

  def sanitize_filename(filename)
    filename.to_s.gsub(/[^[a-zA-Z0-9]\._-]/, "_")
  end
end
