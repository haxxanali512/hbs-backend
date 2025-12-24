# Job to process data imports in the background
require "ostruct"

class DataImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, model_name, user_id, options = {}, send_email: false)
    user = User.find(user_id)

    # Normalize file path (handle spaces and special characters)
    file_path = File.expand_path(file_path)

    unless File.exist?(file_path)
      Rails.logger.error("DataImportJob: File not found at #{file_path}")
      # Send error email if requested
      if send_email
        DataImportMailer.import_complete(
          user: user,
          model_name: model_name,
          result: {
            success_count: 0,
            error_count: 1,
            errors: [ { data: {}, errors: [ "Import file not found. The file may have been deleted or the path is incorrect." ] } ]
          }
        ).deliver_later
      end
      return
    end

    begin
      # Extract original filename from saved path (format: uuid_original_filename)
      # Remove the UUID prefix (format: uuid_original_filename)
      basename = File.basename(file_path)
      # Match UUID pattern at the start followed by underscore
      original_filename = basename.sub(/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}_/, "")

      # Create a file-like object for DataImportService
      # DataImportService expects a file with .path and .original_filename
      file = OpenStruct.new(
        path: file_path,
        original_filename: original_filename
      )

      # Process import
      result = DataImportService.import(
        model_name: model_name,
        file: file,
        **options.symbolize_keys
      )

      # Send email if requested and there are errors (even if some rows succeeded)
      if send_email && result[:error_count] > 0
        DataImportMailer.import_complete(
          user: user,
          model_name: model_name,
          result: result
        ).deliver_later
        Rails.logger.info("DataImportJob: Email notification queued for #{result[:error_count]} failed row(s)")
      end

      result
    ensure
      # Clean up temporary file
      File.delete(file_path) if File.exist?(file_path)
    end
  rescue => e
    Rails.logger.error("DataImportJob error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Send error notification email if requested
    if send_email
      DataImportMailer.import_complete(
        user: user,
        model_name: model_name,
        result: {
          success_count: 0,
          error_count: 1,
          errors: [ { data: {}, errors: [ "Import job failed: #{e.message}" ] } ]
        }
      ).deliver_later
    end

    raise
  end
end
