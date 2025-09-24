class Api::V1::FileUploadsController < ApplicationController
  before_action :validate_file, only: [ :create ]

  def create
    begin
      # Generate unique job ID
      job_id = SecureRandom.uuid

      # Save uploaded file to public folder
      public_file_path = save_file_to_public(job_id)

      # Determine file type
      file_type = determine_file_type(params[:file])

      # Queue the file processing job
      Rails.logger.info "Queuing job with file_path: #{public_file_path}, file_type: #{file_type}, job_id: #{job_id}"
      FileProcessingJob.perform_later(public_file_path, file_type, job_id)

      render json: {
        message: "File uploaded successfully and processing started",
        job_id: job_id,
        file_type: file_type,
        status: "queued"
      }, status: :accepted

    rescue => e
      Rails.logger.error "File upload error: #{e.message}"
      render json: {
        error: "File upload failed",
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

  def validate_file
    unless params[:file].present?
      render json: { error: "No file provided" }, status: :bad_request
      return
    end

    file = params[:file]

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

  def determine_file_type(file)
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
end
