require "securerandom"
require "digest"

class FileProcessingJob < ApplicationJob
  queue_as :default


  def perform(file_path, file_type, job_id = nil, user_id = nil)
    job_id ||= SecureRandom.uuid
    Rails.logger.info "Starting file processing for #{file_path} (Job ID: #{job_id})"
    @errors = []
    @line_number = 1

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

      # Save CSV file to public folder (for reference/export)
      save_csv_to_public_folder(grouped_payments, job_id)

      # Save payment records to database
      save_grouped_payments(grouped_payments, job_id)
    end
      if @errors.any?
        error_path = write_error_csv(job_id)
        notify_error_report(user_id, job_id, error_path)
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
  def notify_error_report(user_id, job_id, error_path)
    user = User.find_by(id: user_id) if user_id.present?
    return if user.nil? && User.joins(:role).where(roles: { role_name: "Super Admin" }).none?

    FileProcessingMailer.errors_report(
      user: user,
      job_id: job_id,
      error_path: error_path,
      error_count: @errors.size
    ).deliver_later
  rescue => e
    Rails.logger.warn "Failed to send file processing error email: #{e.message}"
  end


  def process_csv_file(file_path, job_id)
    Rails.logger.info "Processing CSV file: #{file_path}"

    total_rows = 0
    processed_rows = 0
    batch_size = 1000

    CSV.foreach(file_path, headers: true) do |row|
      total_rows += 1
      @line_number = total_rows + 1 # +1 to account for header row

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
      @line_number = row_num

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

    # Format Remit Patient Name if present
    if row_data["Remit Patient Name"].present?
      formatted_name = format_patient_name(row_data["Remit Patient Name"])
      row_data["Remit Patient Name"] = formatted_name
      Rails.logger.debug "Formatted patient name: #{formatted_name}"
    end

    normalized = normalize_row(row_data)

    # Step 1: Patient Matching (exact first, then fuzzy)
    patient_result = match_patient_xano_style(normalized)
    if patient_result[:success] == false
      record_error(patient_result[:error], normalized, patient_result[:suggested_fix])
      return
    end
    patient = patient_result[:patient]

    # Step 2: Encounter Date Validation
    encounter_date = normalized["Remit Service From Date"]
    if encounter_date.nil?
      record_error("Encounter Date is Required", normalized, "Provide service date")
      return
    end

    # Check if service start != service end (both present)
    service_from = normalized["Remit Service From Date"]
    service_to = normalized["Remit Service to Date"]
    if service_from.present? && service_to.present? && service_from != service_to
      record_error("Service Start Date is different than Service End Date, Flagged!", normalized, "Verify service dates match")
      return
    end

    # Step 3: Encounter Matching
    encounter = match_encounter_xano_style(patient, encounter_date, normalized)
    if encounter.nil?
      return # Error already recorded
    end

    # Step 4: Procedure Code Validation
    procedure_code = normalized["Service Line Procedure Code"]
    if procedure_code.blank?
      record_error("Missing Procedure Code.", normalized, "Provide procedure code")
      return
    end

    procedure_code_record = ProcedureCode.where(code: procedure_code.to_s.strip).first
    if procedure_code_record.nil?
      record_error("Procedure code does not match,", normalized, "Verify procedure code exists")
      return
    end

    # Step 5: Organization Lookup
    organization_name = clean_organization_name(normalized["Remit Account"])
    organization = Organization.where("LOWER(name) = ?", organization_name.downcase).first if organization_name.present?
    if organization.nil?
      record_error("Organization not found, flagged!", normalized, "Verify organization name")
      return
    end

    # Step 6: Build and save payment
    # Add metadata to normalized row for grouping
    normalized["owned_by"] = organization.id
    normalized["encounter_id"] = encounter.id
    normalized["procedure_code_id"] = procedure_code_record.id
    normalized["user_id"] = nil # Will be set from job context if available

    # Store valid record for grouping
    @valid_records ||= []
    @valid_records << normalized

    Rails.logger.debug "Row processed successfully for Job ID: #{job_id} - Patient: #{patient.full_name}, Encounter: #{encounter.id}"
  end

  def normalize_row(row)
    row.transform_values do |v|
      v.is_a?(String) ? v.strip : v
    end.tap do |normalized|
      # Keep formatted (title-case) patient name for display/export; matching uses normalize_name in match_patient_xano_style
      normalized["Remit Service From Date"] = parse_date(normalized["Remit Service From Date"])
      normalized["Remit Service to Date"] = parse_date(normalized["Remit Service to Date"])
      normalized["Remit Received Date"] = parse_date(normalized["Remit Received Date"])
    end
  end

  def match_patient_xano_style(row)
    raw_name = row["Remit Patient Name"].presence
    unless raw_name
      return {
        success: false,
        error: "Patient name missing",
        suggested_fix: "Provide patient name"
      }
    end

    input_name = raw_name.strip
    # Case-insensitive matching: normalize both input and DB names to same form for comparison
    normalized_input = normalize_name_for_matching(input_name)

    # Get all patients with their full names
    all_patients = Patient.kept.select(:id, :first_name, :last_name)

    # Build matches with exact and fuzzy flags (case-insensitive)
    matches = all_patients.map do |p|
      full_name = p.full_name
      normalized_full = normalize_name_for_matching(full_name)

      {
        patient: p,
        full_name: full_name,
        normalized: normalized_full,
        exact_match: normalized_full == normalized_input,
        fuzzy_match: fuzzy_match_similarity(normalized_full, normalized_input, 0.85)
      }
    end

    # Find exact matches
    exact_matches = matches.select { |m| m[:exact_match] }

    if exact_matches.count == 1
      return {
        success: true,
        patient: exact_matches.first[:patient],
        error: "Exact Match found"
      }
    elsif exact_matches.count > 1
      return {
        success: false,
        error: "More than one patient found with the exact same name",
        suggested_fix: "Select correct patient: #{exact_matches.map { |m| "#{m[:patient].id}-#{m[:full_name]}" }.join('; ')}"
      }
    end

    # Find fuzzy matches (excluding exact matches)
    fuzzy_matches = matches.select { |m| m[:fuzzy_match] && !m[:exact_match] }

    if fuzzy_matches.count > 0
      {
        success: false,
        error: "Fuzzy match found (spacing/typo/duplication)",
        suggested_fix: "Select correct patient: #{fuzzy_matches.map { |m| "#{m[:patient].id}-#{m[:full_name]}" }.join('; ')}"
      }
    else
      {
        success: false,
        error: "No matching patient found",
        suggested_fix: "Verify spelling or add patient"
      }
    end
  end

  def match_encounter_xano_style(patient, encounter_date, row)
    scope = Encounter.kept.where(patient_id: patient.id, date_of_service: encounter_date)

    if scope.count == 1
      encounter = scope.first
      # Update encounter status to "Finalized" (matching Xano logic)
      encounter.update(status: :completed_confirmed) if encounter.respond_to?(:status)
      encounter
    elsif scope.count > 1
      record_error("Encounter not found", row, "Multiple encounters found for this date - manual review required")
      nil
    else
      record_error("Encounter not found", row, "Verify encounter date matches patient record")
      nil
    end
  end

  def fuzzy_match_similarity(str1, str2, threshold = 0.85)
    return false if str1.blank? || str2.blank?

    distance = levenshtein_distance(str1, str2)
    max_length = [ str1.length, str2.length ].max
    return false if max_length == 0

    similarity = 1.0 - (distance.to_f / max_length)
    similarity >= threshold
  end

  def record_error(reason, row, suggested_fix = nil)
    @errors << {
      line_number: @line_number,
      reason: reason,
      suggested_fix: suggested_fix,
      row: row
    }
  end

  def processing_sample_headers
    [
      "Remit Account",
      "Remit Patient Name",
      "Remit Service From Date",
      "Remit Service to Date",
      "Remit Received Date",
      "Service Line Procedure Code",
      "Service Line Adjustment CARC",
      "Service Line Total Paid Amount",
      "Remit Total Paid Amount"
    ]
  end

  def write_error_csv(job_id)
    headers = [ "Line Number", "Error Reason", "Suggested Fix" ] + processing_sample_headers
    csv_content = CSV.generate do |csv|
      csv << headers
      @errors.each do |err|
        row = err[:row] || {}
        csv << [
          err[:line_number],
          err[:reason],
          err[:suggested_fix]
        ] + processing_sample_headers.map { |h| row[h] }
      end
    end

    public_dir = Rails.root.join("public", "exports")
    FileUtils.mkdir_p(public_dir)
    path = public_dir.join("errors_#{job_id}.csv")
    File.write(path, csv_content)
    Rails.logger.info "Error sheet written to #{path}"
    path.to_s
  end

  # For display/export: unused in matching; normalize_row keeps formatted name.
  def normalize_name(name)
    return nil if name.blank?
    name.to_s.strip.downcase.squeeze(" ")
  end

  # Case-insensitive patient name matching: normalize to lowercase, single spaces, and consistent order (first last)
  def normalize_name_for_matching(name)
    return nil if name.blank?
    formatted = format_patient_name(name.to_s.strip)
    formatted.to_s.downcase.squeeze(" ")
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.to_s) rescue nil
  end

  def levenshtein_distance(str1, str2)
    a = str1.to_s
    b = str2.to_s
    m = a.length
    n = b.length
    return n if m == 0
    return m if n == 0
    d = Array.new(m+1) { Array.new(n+1) }
    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }
    (1..m).each do |i|
      (1..n).each do |j|
        cost = a[i-1] == b[j-1] ? 0 : 1
        d[i][j] = [
          d[i-1][j] + 1,
          d[i][j-1] + 1,
          d[i-1][j-1] + cost
        ].min
      end
    end
    d[m][n]
  end

  # CSV format is "last_name, first_name". We parse accordingly and return title-case "First Last".
  def format_patient_name(input)
    return "" if input.blank?

    s = input.to_s.strip
    # Format: last_name, first_name (comma-separated)
    name_parts = s.split(",").map(&:strip).reject(&:blank?)

    if name_parts.length == 2
      last_name, first_name = name_parts
      formatted_first = capitalize_name_part(first_name)
      formatted_last = capitalize_name_part(last_name)
      "#{formatted_first} #{formatted_last}"
    else
      # No comma: treat as "First Last" and title-case
      capitalize_name_part(s)
    end
  end

  # Title-case a name (first letter up, rest down); supports multiple words.
  def capitalize_name_part(name)
    return "" if name.blank?

    name.to_s.strip.split(/\s+/).map do |part|
      part.chars.each_with_index.map { |char, i| i == 0 ? char.upcase : char.downcase }.join
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
        payment_status: payment_status,
        encounter_id: entry[:encounter_id],
        procedure_code_id: entry[:procedure_code_id],
        owned_by: entry[:owned_by],
        user_id: entry[:user_id]
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
        payment_status: payment_status,
        encounter_id: entry[:encounter_id],
        procedure_code_id: entry[:procedure_code_id],
        owned_by: entry[:owned_by],
        user_id: entry[:user_id]
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

  def save_grouped_payments(grouped_payments, job_id)
    Rails.logger.info "Creating #{grouped_payments.length} payment records in database for Job ID: #{job_id}"

    created_count = 0
    error_count = 0

    grouped_payments.each do |payment_data|
      begin
        # Get encounter to get organization_id
        encounter = Encounter.find_by(id: payment_data[:encounter_id])
        unless encounter
          Rails.logger.warn "Encounter not found for ID: #{payment_data[:encounter_id]}"
          error_count += 1
          next
        end

        # Determine payment_status from CARC codes
        carc_codes = payment_data[:carc].to_s.split(", ").map(&:strip).reject(&:blank?)
        payment_status = map_carc_to_payment_status(carc_codes)

        # Build notes with CARC codes and payment status info
        notes_parts = []
        notes_parts << "CARC Codes: #{carc_codes.join(', ')}" if carc_codes.any?
        notes_parts << "Payment Status: #{payment_data[:payment_status]}" if payment_data[:payment_status].present?
        notes = notes_parts.join(" | ")

        payer_id = encounter.patient_insurance_coverage&.insurance_plan&.payer_id
        if payer_id.nil?
          Rails.logger.warn "Payer not found for encounter #{encounter.id} (patient_insurance_coverage missing)"
          error_count += 1
          next
        end

        # Build payment record (matching Xano payment_line structure)
        # Note: invoice_id is optional for remit-based payments
        payment = Payment.new(
          invoice_id: nil, # Remit-based payments don't require invoice
          organization_id: payment_data[:owned_by] || encounter.organization_id,
          payer_id: payer_id,
          payment_date: payment_data[:Date_Processed] || payment_data[:Date_Logged],
          amount_total: payment_data[:Amount] || 0.0,
          remit_reference: payment_data[:organization] || "UNKNOWN",
          source_hash: Digest::SHA256.hexdigest("#{job_id}|#{payment_data[:encounter_id]}|#{payment_data[:procedure_code_id]}|#{payment_data[:Date_Processed]}|#{payment_data[:Amount]}"),
          payment_status: payment_status,
          payment_method: :manual,
          processed_by_user_id: payment_data[:user_id],
          notes: notes
        )

        if payment.save
          created_count += 1
          Rails.logger.debug "Payment created: ID #{payment.id} - Amount: $#{payment.amount_total} - Status: #{payment.payment_status} - CARC: #{carc_codes.join(', ')}"

          # Update encounter status to "Finalized" only if payment succeeded (matching Xano logic)
          if payment_status == :succeeded && encounter.respond_to?(:status) && encounter.status != "completed_confirmed"
            encounter.update(status: :completed_confirmed)
            encounter.update(shared_status: :finalized) if encounter.respond_to?(:shared_status)
            Rails.logger.debug "Encounter #{encounter.id} status updated to finalized"
          end
        else
          error_count += 1
          Rails.logger.error "Failed to create payment: #{payment.errors.full_messages.join(', ')}"
        end
      rescue => e
        error_count += 1
        Rails.logger.error "Error creating payment: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
      end
    end

    Rails.logger.info "Payment creation completed: #{created_count} created, #{error_count} errors for Job ID: #{job_id}"
  end

  def map_carc_to_payment_status(carc_codes)
    # CARC code mapping to Payment status enum:
    # "2" or "242" → :succeeded (paid)
    # "1" → :pending (deductible - payment still pending)
    # "0" → :failed (denial)
    # Unknown/missing → :pending (default)

    return :pending if carc_codes.empty?

    # Check for paid status (highest priority)
    if carc_codes.any? { |code| [ "2", "242" ].include?(code) }
      return :succeeded
    end

    # Check for denial
    if carc_codes.include?("0")
      return :failed
    end

    # Check for deductible
    if carc_codes.include?("1")
      return :pending
    end

    # Default to pending for unknown CARC codes
    :pending
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
end
