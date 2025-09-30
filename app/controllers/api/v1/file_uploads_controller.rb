class Api::V1::FileUploadsController < ApplicationController
  before_action :validate_file_or_url, only: [ :create ]

  def create
    begin
      # Generate unique job ID
      job_id = SecureRandom.uuid

      # Handle file upload or URL download
      if params[:file].present?
        # Direct file upload
        public_file_path = save_file_to_public(job_id)
        file_type = determine_file_type_from_upload(params[:file])
        source_type = "upload"
      elsif params[:url].present?
        # URL download
        public_file_path = download_file_from_url(params[:url], job_id)
        file_type = determine_file_type_from_path(public_file_path)
        source_type = "url"
      else
        render json: {
          error: "No file or URL provided",
          message: "Either 'file' or 'url' parameter is required"
        }, status: :bad_request
        return
      end

      # Queue the file processing job
      Rails.logger.info "Queuing job with file_path: #{public_file_path}, file_type: #{file_type}, job_id: #{job_id}, source: #{source_type}"
      FileProcessingJob.perform_later(public_file_path, file_type, job_id)

      render json: {
        message: "File #{source_type == 'upload' ? 'uploaded' : 'downloaded'} successfully and processing started",
        job_id: job_id,
        file_type: file_type,
        source: source_type,
        status: "queued"
      }, status: :accepted

    rescue => e
      Rails.logger.error "File upload/download error: #{e.message}"
      render json: {
        error: "File processing failed",
        message: e.message
      }, status: :unprocessable_entity
    end
  end

  def status
    job_id = params[:job_id]

    if job_id.blank?
      render json: { error: "Job ID is required" }, status: :bad_request
      return
    end

    # In a real implementation, you might want to store job status in Redis or database
    # For now, we'll return a simple response
    render json: {
      job_id: job_id,
      status: "processing", # This would be dynamic in a real implementation
      message: "Check Sidekiq dashboard for detailed status"
    }
  end

  private

  def validate_file_or_url
    # Check if either file or URL is provided
    unless params[:file].present? || params[:url].present?
      render json: {
        error: "No file or URL provided",
        message: "Either 'file' or 'url' parameter is required"
      }, status: :bad_request
      return
    end

    # Validate file upload if provided
    if params[:file].present?
      validate_file_upload(params[:file])
    end

    # Validate URL if provided
    if params[:url].present?
      validate_url
    end
  end

  def validate_file_upload(file)
    # Check file size (e.g., max 100MB)
    max_size = 100.megabytes
    if file.size > max_size
      render json: {
        error: "File too large",
        message: "Maximum file size is #{max_size / 1.megabyte}MB"
      }, status: :payload_too_large
      return
    end

    # Check file type
    allowed_types = %w[.csv .xlsx .xls]
    file_extension = File.extname(file.original_filename).downcase

    unless allowed_types.include?(file_extension)
      render json: {
        error: "Invalid file type",
        message: "Only CSV and Excel files are allowed"
      }, status: :unprocessable_entity
      nil
    end
  end

  def validate_url
    url = params[:url].to_s.strip

    # Basic URL validation
    unless url.match?(/\Ahttps?:\/\/.+/)
      render json: {
        error: "Invalid URL format",
        message: "URL must start with http:// or https://"
      }, status: :unprocessable_entity
      return
    end

    # Check if URL points to a supported file type
    allowed_extensions = %w[.csv .xlsx .xls]
    url_extension = File.extname(URI.parse(url).path).downcase

    unless allowed_extensions.include?(url_extension)
      render json: {
        error: "Unsupported file type in URL",
        message: "URL must point to a CSV or Excel file (.csv, .xlsx, .xls)"
      }, status: :unprocessable_entity
      nil
    end
  rescue URI::InvalidURIError
    render json: {
      error: "Invalid URL",
      message: "Please provide a valid URL"
    }, status: :unprocessable_entity
    nil
  end

  def save_file_to_public(job_id)
    file = params[:file]
    public_dir = Rails.root.join("public", "uploads")

    # Ensure directory exists and is writable
    FileUtils.mkdir_p(public_dir)
    unless File.writable?(public_dir)
      Rails.logger.error "Public upload directory is not writable: #{public_dir}"
      raise "Public upload directory is not writable"
    end

    file_extension = File.extname(file.original_filename)
    public_file_path = public_dir.join("#{job_id}#{file_extension}")

    Rails.logger.info "Saving file to: #{public_file_path}"
    Rails.logger.info "File size: #{file.size} bytes"

    # Read file content once and store it
    file_content = file.read

    # Write file content
    File.open(public_file_path, "wb") do |f|
      f.write(file_content)
    end

    # Verify file was saved correctly and is readable
    if File.exist?(public_file_path) && File.readable?(public_file_path)
      Rails.logger.info "File saved successfully. Size: #{File.size(public_file_path)} bytes"
      Rails.logger.info "File permissions: #{File.stat(public_file_path).mode.to_s(8)}"
    else
      Rails.logger.error "Failed to save file to: #{public_file_path}"
      Rails.logger.error "File exists: #{File.exist?(public_file_path)}"
      Rails.logger.error "File readable: #{File.readable?(public_file_path)}" if File.exist?(public_file_path)
      raise "Failed to save file to public folder"
    end

    public_file_path.to_s
  end

  def download_file_from_url(url, job_id)
    Rails.logger.info "Downloading file from URL: #{url}"

    # Create uploads directory if it doesn't exist
    public_dir = Rails.root.join("public", "uploads")
    FileUtils.mkdir_p(public_dir)

    # Determine file extension from URL
    file_extension = File.extname(URI.parse(url).path)
    public_file_path = public_dir.join("#{job_id}#{file_extension}")

    # Download file using HTTParty
    response = HTTParty.get(url, timeout: 60)

    unless response.success?
      raise "Failed to download file from URL: #{response.code} - #{response.message}"
    end

    # Check file size (max 100MB)
    max_size = 100.megabytes
    if response.body.size > max_size
      raise "Downloaded file too large: #{response.body.size} bytes (max: #{max_size} bytes)"
    end

    # Write downloaded content to file
    File.open(public_file_path, "wb") do |f|
      f.write(response.body)
    end

    # Verify file was saved correctly
    if File.exist?(public_file_path) && File.readable?(public_file_path)
      Rails.logger.info "File downloaded successfully. Size: #{File.size(public_file_path)} bytes"
      Rails.logger.info "File saved to: #{public_file_path}"
    else
      raise "Failed to save downloaded file to: #{public_file_path}"
    end

    public_file_path.to_s
  rescue => e
    Rails.logger.error "URL download error: #{e.message}"
    raise "Failed to download file from URL: #{e.message}"
  end

  def determine_file_type_from_upload(file)
    file_extension = File.extname(file.original_filename).downcase

    case file_extension
    when ".csv"
      "csv"
    when ".xlsx"
      "xlsx"
    when ".xls"
      "xls"
    else
      "unknown"
    end
  end

  def determine_file_type_from_path(file_path)
    file_extension = File.extname(file_path).downcase

    case file_extension
    when ".csv"
      "csv"
    when ".xlsx"
      "xlsx"
    when ".xls"
      "xls"
    else
      "unknown"
    end
  end
end
