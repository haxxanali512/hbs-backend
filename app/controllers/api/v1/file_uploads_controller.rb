class Api::V1::FileUploadsController < ApplicationController
  before_action :validate_file, only: [ :create ]

  def create
    begin
      # Generate unique job ID
      job_id = SecureRandom.uuid

      # Read file content directly
      file_content = params[:file].read
      file_extension = File.extname(params[:file].original_filename)
      file_type = determine_file_type(params[:file])

      Rails.logger.info "File uploaded successfully. Size: #{file_content.bytesize} bytes, Type: #{file_type}, Job ID: #{job_id}"

      # Queue the file processing job with file content
      Rails.logger.info "Queuing job with file_content size: #{file_content.bytesize}, file_type: #{file_type}, job_id: #{job_id}"
      FileProcessingJob.set(wait: 2.seconds).perform_later(file_content, file_extension, file_type, job_id)

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
