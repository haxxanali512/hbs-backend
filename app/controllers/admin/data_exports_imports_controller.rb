require "csv"
require "securerandom"
require "fileutils"

class Admin::DataExportsImportsController < Admin::BaseController
  before_action :load_available_models, only: [ :index ]

  def index
    @action_type = params[:action_type] || "export"
  end

  def download_sample
    model_name = params[:model_name]

    unless model_name.present?
      redirect_to admin_data_exports_imports_path, alert: "Please select a model."
      return
    end

    begin
      model_class = model_name.constantize

      # Generate sample file with headers only
      headers = generate_sample_headers(model_class)
      sample_data = generate_sample_data(model_class, headers)

      format = params[:format] || "csv"
      file_extension = format == "xlsx" ? "csv" : "csv" # For now, always use CSV

      send_data generate_csv_sample(headers, sample_data),
                filename: "#{model_name.downcase}_sample_#{Time.current.strftime('%Y%m%d')}.#{file_extension}",
                type: "text/csv"
    rescue => e
      Rails.logger.error("Error generating sample file: #{e.message}")
      redirect_to admin_data_exports_imports_path, alert: "Error generating sample file: #{e.message}"
    end
  end

  def export
    model_name = params[:model_name]
    format = params[:format] || "csv"

    unless model_name.present?
      redirect_to admin_data_exports_imports_path(action_type: "export"), alert: "Please select a model."
      return
    end

    begin
      # Build filters from params
      filters = build_export_filters(params)

      result = DataExportService.export(
        model_name: model_name,
        filters: filters,
        format: format.to_sym
      )

      send_data result[:content],
                filename: result[:filename],
                type: result[:content_type],
                disposition: "attachment"
    rescue DataExportService::ExportError => e
      Rails.logger.error("Export error: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "export"), alert: "Export failed: #{e.message}"
    rescue => e
      Rails.logger.error("Unexpected export error: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "export"), alert: "Export failed: #{e.message}"
    end
  end

  def import
    model_name = params[:model_name]
    file = params[:file]
    send_email = params[:send_email] == "1"

    unless model_name.present?
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Please select a model."
      return
    end

    unless file.present?
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Please select a file to import."
      return
    end

    begin
      # Save file temporarily for background processing
      temp_file_path = save_temp_file(file)

      # Build options from params (e.g., organization_id)
      options = build_import_options(params)

      # Queue the import job
      DataImportJob.perform_later(
        temp_file_path,
        model_name,
        current_user.id,
        options,
        send_email: send_email
      )

      redirect_to admin_data_exports_imports_path(action_type: "import"),
                  notice: "Import job queued. The import will be processed in the background. #{send_email ? 'You will receive an email with failed rows if any errors occur.' : ''}"
    rescue => e
      Rails.logger.error("Import error: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Import failed: #{e.message}"
    end
  end

  # Uploads a file and queues FileProcessingJob (no job_id needed)
  def upload_processing_file
    file = params[:file]

    unless file.present?
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Please select a file to upload."
      return
    end

    begin
      saved_path = persist_uploaded_file(file)
      file_type = File.extname(file.original_filename).delete(".").downcase

      FileProcessingJob.perform_later(saved_path, file_type, nil, current_user.id)

      redirect_to admin_data_exports_imports_path(action_type: "import"),
                  notice: "File uploaded. Processing has started."
    rescue => e
      Rails.logger.error("Processing file upload failed: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "import"),
                  alert: "Upload failed: #{e.message}"
    end
  end

  # Provides a CSV with the expected headers for processing
  def download_processing_sample
    format = params[:format].presence || "csv"
    file_extension = format == "xlsx" ? "xlsx" : "csv"

    headers = processing_sample_headers
    csv_content = CSV.generate do |csv|
      csv << headers
    end

    send_data csv_content,
              filename: "processing_sample_#{Time.current.strftime('%Y%m%d')}.#{file_extension}",
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def persist_uploaded_file(file)
    dir = Rails.root.join("tmp", "uploads")
    FileUtils.mkdir_p(dir)

    ext = File.extname(file.original_filename)
    filename = "#{SecureRandom.uuid}#{ext}"
    path = dir.join(filename)

    File.open(path, "wb") { |f| f.write(file.read) }
    path.to_s
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

  def load_available_models
    @available_models = [
      { name: "Patient", class: "Patient", description: "Import/Export patient data" },
      { name: "Provider", class: "Provider", description: "Import/Export provider data" },
      { name: "Payer", class: "Payer", description: "Import/Export payer data" },
      { name: "Encounter", class: "Encounter", description: "Import/Export encounter data" },
      { name: "Claim", class: "Claim", description: "Import/Export claim data" },
      { name: "Insurance Plan", class: "InsurancePlan", description: "Import/Export insurance plan data" },
      { name: "Organization Location", class: "OrganizationLocation", description: "Import/Export organization location data" },
      { name: "Specialty", class: "Specialty", description: "Import/Export specialty data" },
      { name: "Procedure Code", class: "ProcedureCode", description: "Import/Export procedure code data" },
      { name: "Diagnosis Code", class: "DiagnosisCode", description: "Import/Export diagnosis code data" },
      { name: "Organization", class: "Organization", description: "Import/Export organization data" },
      { name: "User", class: "User", description: "Import/Export user data" }
    ]
  end

  def generate_sample_headers(model_class)
    # Exclude internal system fields that shouldn't be imported/exported
    excluded_columns = %w[
      id
      created_at updated_at discarded_at
      encrypted_password
      reset_password_token reset_password_sent_at
      confirmation_token confirmed_at confirmation_sent_at unconfirmed_email
      unlock_token locked_at
      invitation_token invitation_created_at invitation_sent_at invitation_accepted_at invitation_limit invited_by_type invited_by_id invitations_count
      remember_created_at
      sign_in_count current_sign_in_at last_sign_in_at current_sign_in_ip last_sign_in_ip
      failed_attempts
      email_verified_at email_verification_at
      activation_state_changed_at closed_at
      cascaded_at
    ]

    # Also exclude any column ending with these patterns (internal fields)
    # But keep important foreign keys and business-relevant datetime fields
    important_foreign_keys = %w[owner_id organization_id role_id specialty_id provider_id patient_id]
    business_datetime_fields = %w[scheduled_start_at scheduled_end_at actual_start_at actual_end_at]

    columns = model_class.column_names.reject do |col|
      excluded_columns.include?(col) ||
      (col.end_with?("_at") && !business_datetime_fields.include?(col)) || # Exclude system timestamps, keep business datetimes
      col.end_with?("_count") || # All counter fields
      col.end_with?("_token") || # All token fields
      col.end_with?("_ip") || # All IP address fields
      col.end_with?("_by_type") || # Polymorphic type fields
      (col.end_with?("_by_id") && !important_foreign_keys.include?(col)) # Polymorphic ID fields (except important FKs)
    end

    headers = columns.map do |col|
      if col.end_with?("_id")
        association_name = col.gsub("_id", "")
        association = model_class.reflect_on_association(association_name.to_sym)
        if association
          # Special handling for Organization owner (User)
          if model_class == Organization && association_name == "owner"
            "owner_email" # Use email instead of name for User
          else
            "#{association_name}_name"
          end
        else
          col
        end
      else
        col.humanize
      end
    end

    # For Organization, append associated OrganizationIdentifier and OrganizationSetting fields
    if model_class == Organization
      headers += [
        # OrganizationIdentifier fields
        "identifier_tax_identification_number",
        "identifier_tax_id_type",
        "identifier_npi",
        "identifier_npi_type",
        "identifier_previous_tin",
        "identifier_previous_npi",
        "identifier_identifiers_change_status",
        "identifier_identifiers_change_docs",
        "identifier_identifiers_change_effective_on",
        # OrganizationSetting fields
        "setting_mrn_prefix",
        "setting_mrn_sequence",
        "setting_mrn_format",
        "setting_mrn_enabled",
        "setting_feature_entitlements",
        "setting_ezclaim_api_token",
        "setting_ezclaim_api_url",
        "setting_ezclaim_api_version",
        "setting_ezclaim_enabled"
      ]
    end

    headers
  end

  def generate_sample_data(model_class, headers)
    # Generate 2-3 sample rows with example data
    sample_rows = []
    2.times do
      row = {}
      headers.each do |header|
        row[header] = generate_sample_value(model_class, header)
      end
      sample_rows << row
    end
    sample_rows
  end

  def generate_sample_value(model_class, header)
    # Generate sample values based on header type
    if header.include?("email")
      "sample@example.com"
    elsif header.include?("username")
      "sample_user"
    elsif header.include?("name")
      "Sample #{header.gsub('_name', '').humanize}"
    elsif header.include?("phone")
      "123-456-7890"
    elsif header.include?("date") || header.include?("dob")
      Date.today.strftime("%Y-%m-%d")
    elsif header.include?("status")
      enum_key = header.gsub("_", "").gsub(" ", "")
      model_class.defined_enums[enum_key]&.keys&.first || model_class.defined_enums["status"]&.keys&.first || "active"
    elsif header.include?("tax_id_type")
      "ein" # Default to EIN for tax ID type
    elsif header.include?("npi_type")
      "type_1" # Default to Type 1 for NPI type
    elsif header.include?("type")
      enum_key = header.gsub("_", "").gsub(" ", "")
      model_class.defined_enums[enum_key]&.keys&.first || "other"
    elsif header.include?("subdomain")
      "sample-org"
    elsif header.include?("password")
      "ChangeThisPassword123!"
    else
      "Sample Value"
    end
  end

  def generate_csv_sample(headers, sample_data)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << headers
      sample_data.each do |row|
        csv << headers.map { |h| row[h] }
      end
    end
  end

  def generate_xlsx_sample(headers, sample_data)
    # For now, generate CSV format (Excel can open CSV files)
    # Excel generation requires additional gems (axlsx, write_xlsx, etc.)
    generate_csv_sample(headers, sample_data)
  end

  def build_export_filters(params)
    filters = {}

    # Common filters
    filters[:organization_id] = params[:organization_id] if params[:organization_id].present?
    filters[:status] = params[:status] if params[:status].present?

    # Date range filters
    if params[:date_from].present? || params[:date_to].present?
      # These will be handled by the service if the model has date_of_service or similar
    end

    filters
  end

  def build_import_options(params)
    options = {}

    # Common options
    options[:organization_id] = params[:organization_id] if params[:organization_id].present?

    options
  end

  def save_temp_file(file)
    # Create temp directory if it doesn't exist
    temp_dir = Rails.root.join("tmp", "imports")
    FileUtils.mkdir_p(temp_dir)

    # Generate unique filename preserving original extension
    # Sanitize filename to remove spaces and special characters that could cause issues
    original_filename = file.original_filename || "import_file.csv"
    sanitized_name = original_filename.gsub(/[^a-zA-Z0-9._-]/, "_")
    filename = "#{SecureRandom.uuid}_#{sanitized_name}"
    temp_path = temp_dir.join(filename)

    # Save file - rewind file pointer first in case it was already read
    file.rewind if file.respond_to?(:rewind)
    File.binwrite(temp_path, file.read)

    # Return absolute path
    temp_path.to_s
  end
end
