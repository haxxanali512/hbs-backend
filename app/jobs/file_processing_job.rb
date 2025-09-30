class FileProcessingJob < ApplicationJob
  queue_as :default

  # Configuration for API format
  API_FORMAT = ENV.fetch("API_FORMAT", "csv").downcase # "json" or "csv"

  def perform(file_path, file_type, job_id)
    Rails.logger.info "Starting file processing for #{file_path} (Job ID: #{job_id})"

    # Check if file exists
    unless File.exist?(file_path)
      Rails.logger.error "File does not exist: #{file_path}"
      raise "File not found: #{file_path}"
    end

    Rails.logger.info "File exists, proceeding with processing. File size: #{File.size(file_path)} bytes"

    begin
      case file_type.downcase
      when "csv"
        process_csv_file(file_path, job_id)
      when "xlsx", "xls"
        process_excel_file(file_path, job_id)
      else
        raise "Unsupported file type: #{file_type}"
      end

      Rails.logger.info "File processing completed successfully for Job ID: #{job_id}"

    # Process and group the payment records
    if @valid_records.present?
      grouped_payments = process_payment_grouping(@valid_records)
      Rails.logger.info "Processed #{grouped_payments.length} grouped payment records"

      # Save CSV file to public folder
      csv_file_path = save_csv_to_public_folder(grouped_payments, job_id)

      # Send data to API and save to database
      save_grouped_payments(grouped_payments, job_id, csv_file_path)
    end

    rescue => e
      Rails.logger.error "File processing failed for Job ID: #{job_id}: #{e.message}"
      raise e
    ensure
      # Clean up the uploaded file after processing is complete
      begin
        if File.exist?(file_path)
          File.delete(file_path)
          Rails.logger.info "Cleaned up uploaded file: #{file_path}"
        else
          Rails.logger.warn "File already deleted or not found: #{file_path}"
        end
      rescue => cleanup_error
        Rails.logger.warn "Failed to clean up uploaded file #{file_path}: #{cleanup_error.message}"
      end
    end
  end

  private

  def process_csv_file(file_path, job_id)
    Rails.logger.info "Processing CSV file: #{file_path}"

    total_rows = 0
    processed_rows = 0
    batch_size = 1000

    CSV.foreach(file_path, headers: true) do |row|
      total_rows += 1

      # Process each row here
      # Example: Create records, validate data, etc.
      process_row(row, job_id)

      processed_rows += 1

      # Log progress every batch_size rows
      if processed_rows % batch_size == 0
        Rails.logger.info "Processed #{processed_rows}/#{total_rows} rows for Job ID: #{job_id}"
      end
    end

    Rails.logger.info "CSV processing completed. Total rows: #{total_rows}, Processed: #{processed_rows}"
  end

  def process_excel_file(file_path, job_id)
    Rails.logger.info "Processing Excel file: #{file_path}"

    begin
      spreadsheet = Roo::Spreadsheet.open(file_path)
      sheet = spreadsheet.sheet(0)

      total_rows = sheet.last_row
      processed_rows = 0
      batch_size = 1000

      # Get headers from first row
      headers = sheet.row(1)

      (2..total_rows).each do |row_num|
        row_data = Hash[headers.zip(sheet.row(row_num))]

        # Process each row here
        # Example: Create records, validate data, etc.
        process_row(row_data, job_id)

        processed_rows += 1

        # Log progress every batch_size rows
        if processed_rows % batch_size == 0
          Rails.logger.info "Processed #{processed_rows}/#{total_rows} rows for Job ID: #{job_id}"
        end
      end

      Rails.logger.info "Excel processing completed. Total rows: #{total_rows}, Processed: #{processed_rows}"
    ensure
      spreadsheet&.close
    end
  end

  def process_row(row_data, job_id)
    # Normalize CSV rows to plain Hash for consistent downstream handling
    if defined?(CSV) && row_data.is_a?(CSV::Row)
      row_data = row_data.to_h
    end
    # Implement your specific data processing logic here
    # This is where you would:
    # - Validate the data
    # - Transform the data
    # - Save to database
    # - Send notifications
    # - etc.

    # Format Remit Patient Name if present
    if row_data["Remit Patient Name"].present?
      formatted_name = format_patient_name(row_data["Remit Patient Name"])
      row_data["Remit Patient Name"] = formatted_name
      Rails.logger.debug "Formatted patient name: #{formatted_name}"
    end

    # Store the row for later grouping and processing
    @valid_records ||= []
    @valid_records << row_data

    # Example processing (replace with your actual logic):
    Rails.logger.debug "Processing row for Job ID: #{job_id} - #{row_data.inspect}"

    # Simulate some processing time
    sleep(0.001) # Remove this in production
  end

  def format_patient_name(input)
    return "" if input.blank?

    # Split by comma and trim whitespace
    name_parts = input.split(",").map(&:strip)

    # If we don't have exactly 2 parts, return original
    return input if name_parts.length != 2

    last_name, first_name = name_parts

    # Capitalize each part (first letter uppercase, rest lowercase)
    formatted_first_name = capitalize_name(first_name)
    formatted_last_name = capitalize_name(last_name)

    # Return as "FirstName LastName"
    "#{formatted_first_name} #{formatted_last_name}"
  end

  def capitalize_name(name)
    return "" if name.blank?

    name.strip.split(" ").map do |part|
      part.chars.each_with_index.map do |char, index|
        index == 0 ? char.upcase : char.downcase
      end.join
    end.join(" ")
  end

  def process_payment_grouping(valid_records)
    # Status mapping for CARC codes - only these specific codes are valid
    status_map = {
      "242" => "Paid",
      "2" => "Paid",
      "1" => "Deductible",
      "0" => "Denial"
    }

    # Valid CARC codes that should be processed
    valid_carc_codes = [ "242", "2", "1", "0" ]

    # Group records by their key fields - only group if CARC is "2" or "242" (PAID)
    grouped = {}
    individual_records = []

    valid_records.each do |item|
      # Debug: Log available fields to see what CARC field name is
      if valid_records.index(item) == 0
        Rails.logger.info "Available fields in first record: #{item.keys.join(', ')}"
        Rails.logger.info "Looking for CARC field. Available CARC-related fields: #{item.keys.select { |k| k.downcase.include?('carc') }.join(', ')}"
      end

      # Get CARC code first to determine if we should group
      carc_value = item["Servie Line Adjustment CARC"] ||
                   item["Service Line Adjustment CARC"] ||
                   item["CARC"] ||
                   item["carc"] ||
                   item["Servie Line Adjustment"] ||
                   item["Service Line Adjustment"]

      # Only group records with CARC codes "2" or "242" (PAID status)
      if carc_value.present? && [ "2", "242" ].include?(carc_value.to_s.strip)
        # Create grouping key from the specified fields (excluding CARC codes)
        key = {
          patient: item["Remit Patient Name"],
          Encounter_Date: item["Remit Service From Date"],
          Encounter_Date2: item["Remit Service to Date"],
          organization: clean_organization_name(item["Remit Account"]),
          Amount: item["Remit Total Paid Amount"],
          Date_Processed: item["Remit Received Date"],
          Date_Logged: item["Remit Received Date"],
          procedure_code: item["Service Line Procedure Code"],
          owned_by: item["owned_by"],
          procedure_code_id: item["procedure_code_id"],
          encounter_id: item["encounter_id"],
          user_id: item["user_id"]
        }.to_json

        if grouped[key].nil?
          grouped[key] = {
            patient: item["Remit Patient Name"],
            Encounter_Date: item["Remit Service From Date"],
            Encounter_Date2: item["Remit Service to Date"],
            organization: clean_organization_name(item["Remit Account"]),
            Amount: item["Remit Total Paid Amount"],
            Date_Processed: item["Remit Received Date"],
            Date_Logged: item["Remit Received Date"],
            procedure_code: item["Service Line Procedure Code"],
            owned_by: item["owned_by"],
            procedure_code_id: item["procedure_code_id"],
            encounter_id: item["encounter_id"],
            user_id: item["user_id"],
            carc_set: Set.new
          }
        end

        # Add CARC code to the set
        grouped[key][:carc_set].add(carc_value.to_s.strip)
        Rails.logger.debug "Added PAID CARC code: #{carc_value} for patient: #{item['Remit Patient Name']} - will be grouped"
      else
        # For non-PAID CARC codes or no CARC code, process individually
        # Add ALL CARC codes to the set (both valid and invalid)
        carc_set = Set.new
        if carc_value.present?
          carc_set.add(carc_value.to_s.strip)
        end

        individual_records << {
          patient: item["Remit Patient Name"],
          Encounter_Date: item["Remit Service From Date"],
          Encounter_Date2: item["Remit Service to Date"],
          organization: clean_organization_name(item["Remit Account"]),
          Amount: item["Remit Total Paid Amount"],
          Date_Processed: item["Remit Received Date"],
          Date_Logged: item["Remit Received Date"],
          procedure_code: item["Service Line Procedure Code"],
          owned_by: item["owned_by"],
          procedure_code_id: item["procedure_code_id"],
          encounter_id: item["encounter_id"],
          user_id: item["user_id"],
          carc_set: carc_set
        }
        Rails.logger.debug "Added individual record for patient: #{item['Remit Patient Name']} with CARC: #{carc_value || 'none'}"
      end
    end

    Rails.logger.info "Grouped #{valid_records.length} records into #{grouped.length} groups and #{individual_records.length} individual records"

    # Process grouped records and individual records
    grouped_results = grouped.values.map do |entry|
      carc_array = entry[:carc_set].to_a.sort

      # Calculate payment status from CARC codes
      if carc_array.empty?
        payment_status = "unknown"
        Rails.logger.debug "Group: #{entry[:patient]} - No valid CARC codes - Status: #{payment_status}"
      else
        payment_status = carc_array
          .map { |code| status_map[code] }
          .uniq
          .join(", ")
        Rails.logger.debug "Group: #{entry[:patient]} - CARC codes: #{carc_array.join(', ')} - Status: #{payment_status}"
      end

      {
        patient: entry[:patient],
        Encounter_Date: entry[:Encounter_Date],
        Encounter_Date2: entry[:Encounter_Date2],
        organization: entry[:organization],
        Amount: parse_currency(entry[:Amount]),
        carc: carc_array.join(", "),
        Date_Processed: entry[:Date_Processed],
        Date_Logged: entry[:Date_Logged],
        procedure_code: entry[:procedure_code],
        payment_status: payment_status
      }
    end

    # Process individual records (non-PAID CARC codes)
    individual_results = individual_records.map do |entry|
      carc_array = entry[:carc_set].to_a.sort

      # Calculate payment status from CARC codes
      if carc_array.empty?
        payment_status = "unknown"
        Rails.logger.debug "Individual record: #{entry[:patient]} - No CARC codes - Status: #{payment_status}"
      else
        # Map valid CARC codes to status, invalid ones get "unknown"
        statuses = carc_array.map do |code|
          status_map[code] || "unknown"
        end
        payment_status = statuses.uniq.join(", ")
        Rails.logger.debug "Individual record: #{entry[:patient]} - CARC codes: #{carc_array.join(', ')} - Status: #{payment_status}"
      end

      {
        patient: entry[:patient],
        Encounter_Date: entry[:Encounter_Date],
        Encounter_Date2: entry[:Encounter_Date2],
        organization: entry[:organization],
        Amount: parse_currency(entry[:Amount]),
        carc: carc_array.join(", "),
        Date_Processed: entry[:Date_Processed],
        Date_Logged: entry[:Date_Logged],
        procedure_code: entry[:procedure_code],
        payment_status: payment_status
      }
    end

    # Combine grouped and individual results
    grouped_results + individual_results
  end

  def parse_currency(value)
    return 0.0 if value.blank?

    # Remove any non-digit, non-decimal characters (like $ or commas)
    cleaned = value.to_s.gsub(/[^0-9.]/, "")
    cleaned.to_f
  end

  def clean_string(value)
    return "" if value.blank?

    # Clean and normalize string values
    value.to_s.strip
  end

  def clean_organization_name(value)
    return "" if value.blank?

    # Remove numbers in parentheses from organization name
    # Example: "C Jay's Management Corporation (292008)" -> "C Jay's Management Corporation"
    cleaned = value.to_s.strip
    cleaned.gsub(/\s*\(\d+\)\s*$/, "").strip
  end

  def save_csv_to_public_folder(grouped_payments, job_id)
    # Create public/exports directory if it doesn't exist
    public_dir = Rails.root.join("public", "exports")
    FileUtils.mkdir_p(public_dir)

    # Generate CSV filename with timestamp
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    csv_filename = "processed_payments_#{job_id}_#{timestamp}.csv"
    csv_file_path = public_dir.join(csv_filename)

    # Generate CSV content
    csv_content = generate_csv_data(grouped_payments)

    # Write CSV file
    File.write(csv_file_path, csv_content)

    Rails.logger.info "CSV file saved to: #{csv_file_path}"
    Rails.logger.info "CSV file size: #{File.size(csv_file_path)} bytes"

    # Return the public URL path
    "/exports/#{csv_filename}"
  end

  def save_grouped_payments(grouped_payments, job_id, csv_file_path = nil)
    Rails.logger.info "Sending #{grouped_payments.length} grouped payment records to API for Job ID: #{job_id}"

    # Log the first few records for debugging
    grouped_payments.first(3).each_with_index do |payment, index|
      Rails.logger.debug "Payment #{index + 1}: #{payment[:patient]} - #{payment[:payment_status]} - $#{payment[:Amount]}"
    end

    begin
      # Send data to the API based on configuration
      if API_FORMAT == "csv"
        send_csv_to_api(grouped_payments, job_id, csv_file_path)
      else
        send_to_api(grouped_payments, job_id, csv_file_path)
      end
      Rails.logger.info "Successfully sent payment data to API for Job ID: #{job_id}"
    rescue => e
      Rails.logger.error "Failed to send payment data to API for Job ID: #{job_id}: #{e.message}"
      raise e
    end
  end

  def send_to_api(payment_data, job_id, csv_file_path = nil)
    api_url = "https://xhnq-ezxv-7zvm.n7d.xano.io/api:AmT5eNEe:v2/payment/upload_payment"

    # Prepare the payload
    payload = {
      job_id: job_id,
      processed_at: Time.current.iso8601,
      record_count: payment_data.length,
      data: payment_data
    }

    # Add CSV file path if available
    if csv_file_path.present?
      payload[:csv_file_path] = csv_file_path
      # Generate download URL - use relative path if host is not configured
      begin
        payload[:csv_download_url] = "#{Rails.application.routes.url_helpers.root_url.chomp('/')}#{csv_file_path}"
      rescue => e
        Rails.logger.warn "Could not generate full URL, using relative path: #{e.message}"
        payload[:csv_download_url] = csv_file_path
      end
    end

    Rails.logger.info "Sending #{payment_data.length} records to API: #{api_url}"
    Rails.logger.info "Sending payload: #{payload}"

    # Make HTTP request
    response = HTTParty.post(
      api_url,
      body: payload.to_json,
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      },
      timeout: 30
    )

    if response.success?
      Rails.logger.info "API response: #{response.code} - #{response.message}"
      Rails.logger.debug "API response body: #{response.body}" if response.body.present?
    else
      Rails.logger.error "API request failed: #{response.code} - #{response.message}"
      Rails.logger.error "API response body: #{response.body}" if response.body.present?
      raise "API request failed with status #{response.code}: #{response.message}"
    end

    response
  end

  def generate_csv_data(payment_data)
    return "" if payment_data.empty?

    # Get headers from the first record
    headers = payment_data.first.keys

    # Generate CSV content
    csv_content = CSV.generate do |csv|
      # Add headers
      csv << headers

      # Add data rows
      payment_data.each do |record|
        csv << headers.map { |header| record[header] }
      end
    end

    csv_content
  end

  def send_csv_to_api(payment_data, job_id, csv_file_path = nil)
    api_url = "https://xhnq-ezxv-7zvm.n7d.xano.io/api:AmT5eNEe:v2/payment/upload_payment"

    # Generate CSV data and save to temporary file
    csv_content = generate_csv_data(payment_data)
    temp_file = Tempfile.new([ "payment_data", ".csv" ])
    temp_file.write(csv_content)
    temp_file.rewind
    Rails.logger.info "Uploading #{payment_data.length} records as CSV file to API: #{api_url}"

    begin
      # Make HTTP request with file upload
      response = HTTParty.post(
        api_url,
        body: {
          file: File.open(temp_file.path, "rb")
        },
        timeout: 30
      )

      if response.success?
        Rails.logger.info "CSV file uploaded successfully to API: #{response.code} - #{response.message}"
        Rails.logger.debug "API response body: #{response.body}" if response.body.present?
      else
        Rails.logger.error "CSV file upload failed: #{response.code} - #{response.message}"
        Rails.logger.error "API response body: #{response.body}" if response.body.present?
        raise "API request failed with status #{response.code}: #{response.message}"
      end

      response
    ensure
      # Clean up temporary file
      temp_file.close
      temp_file.unlink
    end
  end
end
