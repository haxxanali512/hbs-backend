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

    unless model_name.present?
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Please select a model."
      return
    end

    unless file.present?
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Please select a file to import."
      return
    end

    begin
      # Build options from params (e.g., organization_id)
      options = build_import_options(params)

      result = DataImportService.import(
        model_name: model_name,
        file: file,
        **options
      )

      if result[:error_count] == 0
        redirect_to admin_data_exports_imports_path(action_type: "import"),
                    notice: "Successfully imported #{result[:success_count]} record(s)."
      elsif result[:success_count] > 0
        redirect_to admin_data_exports_imports_path(action_type: "import"),
                    alert: "Imported #{result[:success_count]} record(s) with #{result[:error_count]} error(s). Check logs for details."
      else
        redirect_to admin_data_exports_imports_path(action_type: "import"),
                    alert: "Import failed. #{result[:errors].first[:errors].join(', ')}"
      end
    rescue DataImportService::ImportError => e
      Rails.logger.error("Import error: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Import failed: #{e.message}"
    rescue => e
      Rails.logger.error("Unexpected import error: #{e.message}")
      redirect_to admin_data_exports_imports_path(action_type: "import"), alert: "Import failed: #{e.message}"
    end
  end

  private

  def load_available_models
    @available_models = [
      { name: "Patient", class: "Patient", description: "Import/Export patient data" },
      { name: "Provider", class: "Provider", description: "Import/Export provider data" },
      { name: "Payer", class: "Payer", description: "Import/Export payer data" },
      { name: "Encounter", class: "Encounter", description: "Import/Export encounter data" },
      { name: "Claim", class: "Claim", description: "Import/Export claim data" },
      { name: "Insurance Plan", class: "InsurancePlan", description: "Import/Export insurance plan data" },
      { name: "Organization Location", class: "OrganizationLocation", description: "Import/Export organization location data" },
      { name: "Specialty", class: "Specialty", description: "Import/Export specialty data" }
    ]
  end

  def generate_sample_headers(model_class)
    excluded_columns = %w[id created_at updated_at discarded_at]
    columns = model_class.column_names.reject { |col| excluded_columns.include?(col) }

    columns.map do |col|
      if col.end_with?("_id")
        association_name = col.gsub("_id", "")
        association = model_class.reflect_on_association(association_name.to_sym)
        if association
          "#{association_name}_name"
        else
          col
        end
      else
        col.humanize
      end
    end
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
    if header.include?("name")
      "Sample #{header.gsub('_name', '').humanize}"
    elsif header.include?("email")
      "sample@example.com"
    elsif header.include?("phone")
      "123-456-7890"
    elsif header.include?("date") || header.include?("dob")
      Date.today.strftime("%Y-%m-%d")
    elsif header.include?("status")
      model_class.defined_enums[header.gsub("_", "")]&.keys&.first || "active"
    elsif header.include?("type")
      model_class.defined_enums[header.gsub("_", "")]&.keys&.first || "other"
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
end
