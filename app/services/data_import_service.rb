# Service for importing data from CSV/Excel
class DataImportService
  class ImportError < StandardError; end

  # Import data from uploaded file
  # Usage: DataImportService.import(model_name: "Patient", file: uploaded_file, organization_id: 1)
  def self.import(model_name:, file:, **options)
    service = new(model_name: model_name, file: file, **options)
    service.perform
  end

  def initialize(model_name:, file:, **options)
    @model_name = model_name
    @file = file
    @options = options
    @model_class = model_name.constantize
    @results = {
      success_count: 0,
      error_count: 0,
      errors: []
    }
  end

  def perform
    validate_model!
    validate_file!

    data = parse_file
    process_rows(data)

    @results
  end

  private

  attr_reader :model_name, :file, :options, :model_class, :results

  def validate_model!
    unless @model_class < ActiveRecord::Base
      raise ImportError, "Invalid model: #{model_name}"
    end
  end

  def validate_file!
    unless file.present?
      raise ImportError, "No file provided"
    end

    extension = File.extname(file.original_filename).downcase
    unless [ ".csv", ".xlsx", ".xls" ].include?(extension)
      raise ImportError, "Unsupported file format. Please upload CSV or Excel file."
    end
  end

  def parse_file
    extension = File.extname(file.original_filename).downcase

    case extension
    when ".csv"
      parse_csv
    when ".xlsx", ".xls"
      parse_excel
    else
      raise ImportError, "Unsupported file format"
    end
  end

  def parse_csv
    require "csv"

    csv_data = CSV.read(file.path, headers: true)
    csv_data.map(&:to_h)
  rescue => e
    raise ImportError, "Error parsing CSV: #{e.message}"
  end

  def parse_excel
    require "roo"

    spreadsheet = Roo::Spreadsheet.open(file.path)
    sheet = spreadsheet.sheet(0)

    headers = sheet.row(1)
    data = []

    (2..sheet.last_row).each do |row_num|
      row_data = {}
      headers.each_with_index do |header, index|
        row_data[header.to_s] = sheet.cell(row_num, index + 1)
      end
      data << row_data if row_data.values.any?(&:present?)
    end

    data
  rescue => e
    raise ImportError, "Error parsing Excel: #{e.message}"
  end

  def process_rows(data)
    data.each_with_index do |row_data, index|
      begin
        record = build_record(row_data)
        if record.save
          @results[:success_count] += 1
        else
          @results[:error_count] += 1
          @results[:errors] << {
            row: index + 2, # +2 because of header row and 0-based index
            data: row_data,
            errors: record.errors.full_messages
          }
        end
      rescue => e
        @results[:error_count] += 1
        @results[:errors] << {
          row: index + 2,
          data: row_data,
          errors: [ e.message ]
        }
      end
    end
  end

  def build_record(row_data)
    # Normalize keys (handle spaces, case differences)
    normalized_data = normalize_row_data(row_data)

    # Map CSV headers to model attributes
    attributes = map_attributes(normalized_data)

    # Find or initialize record
    find_by_attributes = extract_find_by_attributes(attributes)
    record = if find_by_attributes.any?
      @model_class.find_or_initialize_by(find_by_attributes)
    else
      @model_class.new
    end

    # Assign attributes
    record.assign_attributes(attributes.except(*find_by_attributes.keys))

    record
  end

  def normalize_row_data(row_data)
    normalized = {}
    row_data.each do |key, value|
      # Normalize key: remove spaces, downcase, convert to snake_case
      normalized_key = key.to_s.downcase.gsub(/\s+/, "_").gsub(/[^a-z0-9_]/, "")
      normalized[normalized_key] = value
    end
    normalized
  end

  def map_attributes(normalized_data)
    attributes = {}

    normalized_data.each do |key, value|
      next if value.blank?

      # Check if it's a direct column
      if @model_class.column_names.include?(key)
        attributes[key] = parse_value(key, value)
      # Check if it's an association (e.g., "organization_name")
      elsif key.end_with?("_name")
        association_name = key.gsub("_name", "")
        association_id = find_association_id(association_name, value)
        attributes["#{association_name}_id"] = association_id if association_id
      # Check if it's a foreign key
      elsif key.end_with?("_id")
        attributes[key] = value.to_i if value.to_s.match?(/^\d+$/)
      end
    end

    # Apply default options (e.g., organization_id from params)
    options.each do |key, value|
      if @model_class.column_names.include?(key.to_s)
        attributes[key.to_s] = value
      end
    end

    attributes
  end

  def parse_value(column_name, value)
    column = @model_class.columns_hash[column_name]
    return value unless column

    case column.type
    when :integer, :bigint
      value.to_i rescue value
    when :decimal, :float
      value.to_f rescue value
    when :boolean
      [ "true", "1", "yes", "y" ].include?(value.to_s.downcase)
    when :date
      Date.parse(value) rescue value
    when :datetime, :timestamp
      DateTime.parse(value) rescue value
    else
      value
    end
  end

  def find_association_id(association_name, value)
    association = @model_class.reflect_on_association(association_name.to_sym)
    return nil unless association

    associated_model = association.class_name.constantize

    # Try to find by name
    if associated_model.respond_to?(:find_by_name)
      record = associated_model.find_by_name(value)
      return record.id if record
    end

    # Try to find by full_name
    if associated_model.respond_to?(:find_by_full_name)
      record = associated_model.find_by_full_name(value)
      return record.id if record
    end

    # Try case-insensitive search
    if associated_model.column_names.include?("name")
      record = associated_model.where("name ILIKE ?", value).first
      return record.id if record
    end

    nil
  end

  def extract_find_by_attributes(attributes)
    # Use unique identifiers to find existing records
    find_by = {}

    # Priority: external_id, mrn, email, npi, code (with code_type if applicable)
    if attributes["external_id"].present?
      find_by["external_id"] = attributes["external_id"]
    elsif attributes["mrn"].present? && attributes["organization_id"].present?
      find_by["mrn"] = attributes["mrn"]
      find_by["organization_id"] = attributes["organization_id"]
    elsif attributes["email"].present?
      find_by["email"] = attributes["email"]
    elsif attributes["npi"].present?
      find_by["npi"] = attributes["npi"]
    elsif attributes["code"].present?
      # For ProcedureCode: code + code_type is unique
      # For DiagnosisCode: code is unique
      find_by["code"] = attributes["code"]
      if attributes["code_type"].present? && @model_class.column_names.include?("code_type")
        find_by["code_type"] = attributes["code_type"]
      end
    end

    find_by
  end
end
