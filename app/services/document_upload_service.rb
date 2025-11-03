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

    file_info = store_file

    document = create_document
    create_attachment(document, file_info)

    { success: true, document: document }
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

  def store_file
    if use_s3?
      store_to_s3
    else
      store_locally
    end
  end

  def use_s3?
    Rails.env.production?
  end

  def store_locally
    dir_path = Rails.root.join("public", "uploads", documentable_type, documentable.id.to_s)
    FileUtils.mkdir_p(dir_path)

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    sanitized = sanitize_filename(uploaded_io.original_filename)
    stored_filename = "#{timestamp}_#{sanitized}"
    stored_path = dir_path.join(stored_filename)

    File.open(stored_path, "wb") { |f| f.write(uploaded_io.read) }

    file_size = File.size(stored_path)
    file_hash = Digest::SHA256.file(stored_path).hexdigest
    relative_path = stored_path.to_s.sub(Rails.root.join("public").to_s, "")

    {
      file_path: relative_path,
      file_size: file_size,
      file_hash: file_hash,
      file_name: uploaded_io.original_filename,
      file_type: uploaded_io.content_type
    }
  end

  def store_to_s3
    require "aws-sdk-s3" unless defined?(Aws::S3)

    s3_client = Aws::S3::Client.new(
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
      region: Rails.application.credentials.dig(:aws, :region) || "us-east-1"
    )

    bucket_name = Rails.application.credentials.dig(:aws, :bucket_name) || "hbs-documents-#{Rails.env}"
    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    sanitized = sanitize_filename(uploaded_io.original_filename)
    key = "#{documentable_type}/#{documentable.id}/#{timestamp}_#{sanitized}"

    # Read file content
    file_content = uploaded_io.read
    file_size = file_content.bytesize
    file_hash = Digest::SHA256.hexdigest(file_content)

    # Upload to S3
    s3_client.put_object(
      bucket: bucket_name,
      key: key,
      body: file_content,
      content_type: uploaded_io.content_type,
      metadata: {
        "uploaded-by" => uploaded_by.id.to_s,
        "organization-id" => organization.id.to_s,
        "documentable-type" => documentable_type,
        "documentable-id" => documentable.id.to_s
      }
    )

    # Generate public URL (or presigned URL for private buckets)
    file_url = s3_client.presigned_url(
      :get_object,
      bucket: bucket_name,
      key: key,
      expires_in: 1.year.to_i
    )

    {
      file_path: file_url, # Store S3 URL in file_path
      file_size: file_size,
      file_hash: file_hash,
      file_name: uploaded_io.original_filename,
      file_type: uploaded_io.content_type,
      s3_key: key,
      s3_bucket: bucket_name
    }
  rescue Aws::S3::Errors::ServiceError => e
    raise UploadError, "S3 upload failed: #{e.message}"
  end

  def create_document
    documentable.documents.create!(
      title: title,
      description: description,
      status: "pending",
      document_type: document_type,
      created_by: uploaded_by,
      organization: organization
    )
  end

  def create_attachment(document, file_info)
    document.document_attachments.create!(
      file_name: file_info[:file_name],
      file_type: file_info[:file_type],
      file_size: file_info[:file_size],
      file_path: file_info[:file_path], # S3 URL in production, local path in dev/staging
      file_hash: file_info[:file_hash],
      uploaded_by: uploaded_by,
      is_primary: true
    )
  end

  def documentable_type
    documentable.class.name.underscore.pluralize
  end

  def sanitize_filename(filename)
    filename.to_s.gsub(/[^[a-zA-Z0-9]\._-]/, "_")
  end
end
