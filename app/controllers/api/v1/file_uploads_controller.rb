class Api::V1::FileUploadsController < ApplicationController
  before_action :validate_file, only: [ :create ]

  def create
    begin
      # Generate unique job ID
      job_id = SecureRandom.uuid

      # Save uploaded file temporarily
      temp_file_path = save_temp_file(job_id)

      # Determine file type
      file_type = determine_file_type(params[:file])

      # Verify file exists before queuing job
      unless File.exist?(temp_file_path)
        Rails.logger.error "File does not exist before queuing job: #{temp_file_path}"
        raise "File not found before queuing job"
      end

      # Queue the file processing job with a delay to ensure file is written
      Rails.logger.info "Queuing job with file_path: #{temp_file_path}, file_type: #{file_type}, job_id: #{job_id}"
      FileProcessingJob.set(wait: 5.seconds).perform_later(temp_file_path, file_type, job_id)

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

  def save_temp_file(job_id)
    file = params[:file]
    temp_dir = Rails.root.join("tmp", "uploads")

    # Ensure directory exists and is writable
    FileUtils.mkdir_p(temp_dir)
    unless File.writable?(temp_dir)
      Rails.logger.error "Upload directory is not writable: #{temp_dir}"
      raise "Upload directory is not writable"
    end

    file_extension = File.extname(file.original_filename)
    temp_file_path = temp_dir.join("#{job_id}#{file_extension}")

    Rails.logger.info "Saving file to: #{temp_file_path}"
    Rails.logger.info "File size: #{file.size} bytes"

    # Copy file directly to avoid memory issues
    File.open(temp_file_path, "wb") do |output_file|
      file.rewind if file.respond_to?(:rewind)
      IO.copy_stream(file, output_file)
    end

    # Verify file was saved correctly and is readable
    if File.exist?(temp_file_path) && File.readable?(temp_file_path)
      Rails.logger.info "File saved successfully. Size: #{File.size(temp_file_path)} bytes"
      Rails.logger.info "File permissions: #{File.stat(temp_file_path).mode.to_s(8)}"
    else
      Rails.logger.error "Failed to save file to: #{temp_file_path}"
      Rails.logger.error "File exists: #{File.exist?(temp_file_path)}"
      Rails.logger.error "File readable: #{File.readable?(temp_file_path)}" if File.exist?(temp_file_path)
      raise "Failed to save temporary file"
    end

    temp_file_path.to_s
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

  def create_backup_file(original_file_path, job_id)
    # Create a backup in a more persistent location
    backup_dir = Rails.root.join("tmp", "backups")
    FileUtils.mkdir_p(backup_dir)

    file_extension = File.extname(original_file_path)
    backup_file_path = backup_dir.join("#{job_id}_backup#{file_extension}")

    # Copy the file to backup location
    FileUtils.cp(original_file_path, backup_file_path)

    Rails.logger.info "Created backup file: #{backup_file_path}"
    backup_file_path.to_s
  end
end
