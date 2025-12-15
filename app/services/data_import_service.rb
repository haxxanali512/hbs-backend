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
    # Nested attrs for Organization associations
    @organization_identifier_attrs = {}
    @organization_setting_attrs = {}
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

    # Special validation for Organization: owner_id must be present
    if @model_class == Organization && attributes["owner_id"].blank?
      # Try to find owner from normalized_data
      if normalized_data["owner_email"].present?
        owner = User.find_by(email: normalized_data["owner_email"])
        attributes["owner_id"] = owner.id if owner
      elsif normalized_data["owner_username"].present?
        owner = User.find_by(username: normalized_data["owner_username"])
        attributes["owner_id"] = owner.id if owner
      end
    end

    # Find or initialize record
    find_by_attributes = extract_find_by_attributes(attributes)
    record = if find_by_attributes.any?
      @model_class.find_or_initialize_by(find_by_attributes)
    else
      @model_class.new
    end

    # Assign attributes
    record.assign_attributes(attributes.except(*find_by_attributes.keys))

    # Assign nested OrganizationIdentifier / OrganizationSetting for Organization imports
    if @model_class == Organization
      if @organization_identifier_attrs.present?
        record.build_organization_identifier unless record.organization_identifier
        record.organization_identifier.assign_attributes(@organization_identifier_attrs)
      end

      if @organization_setting_attrs.present?
        record.build_organization_setting unless record.organization_setting
        record.organization_setting.assign_attributes(@organization_setting_attrs)
      end
    end

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

    # Reset nested attrs per row
    if @model_class == Organization
      @organization_identifier_attrs = {}
      @organization_setting_attrs = {}
    end

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
      # Special handling for owner_email and owner_username (for Organization)
      elsif key == "owner_email" && @model_class == Organization
        owner = User.find_by(email: value)
        attributes["owner_id"] = owner.id if owner
      elsif key == "owner_username" && @model_class == Organization
        owner = User.find_by(username: value)
        attributes["owner_id"] = owner.id if owner
      # Nested OrganizationIdentifier fields
      elsif @model_class == Organization && key.start_with?("identifier_")
        nested_key = key.sub("identifier_", "")
        @organization_identifier_attrs[nested_key] = parse_associated_value(OrganizationIdentifier, nested_key, value)
      # Nested OrganizationSetting fields
      elsif @model_class == Organization && key.start_with?("setting_")
        nested_key = key.sub("setting_", "")
        @organization_setting_attrs[nested_key] = parse_associated_value(OrganizationSetting, nested_key, value)
      end
    end

    # Apply default options (e.g., organization_id from params)
    options.each do |key, value|
      if @model_class.column_names.include?(key.to_s)
        attributes[key.to_s] = value
      end
    end

    # Special handling for User password
    if @model_class == User && attributes["password"].blank? && attributes["encrypted_password"].blank?
      # Generate a random password if not provided
      # User will need to reset password via email
      require "securerandom"
      attributes["password"] = SecureRandom.alphanumeric(16)
    end

    attributes
  end

  def parse_value(column_name, value)
    column = @model_class.columns_hash[column_name]
    return value unless column

    # Handle enum fields (stored as integers but can accept string values)
    if @model_class.respond_to?(:defined_enums) && @model_class.defined_enums.key?(column_name.to_s)
      enum_values = @model_class.defined_enums[column_name.to_s]
      # Try to find by string key (e.g., "pending", "active")
      if enum_values.key?(value.to_s.downcase)
        return enum_values[value.to_s.downcase]
      # Try to find by integer value
      elsif value.to_s.match?(/^\d+$/) && enum_values.values.include?(value.to_i)
        return value.to_i
      end
    end

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

  def parse_associated_value(associated_class, column_name, value)
    column = associated_class.columns_hash[column_name]
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
    when :json, :jsonb
      begin
        value.is_a?(String) ? JSON.parse(value) : value
      rescue JSON::ParserError
        value
      end
    else
      value
    end
  end

  def find_association_id(association_name, value)
    association = @model_class.reflect_on_association(association_name.to_sym)
    return nil unless association

    associated_model = association.class_name.constantize

    # Special handling for User (owner association)
    if associated_model == User
      # Try to find by email first
      record = associated_model.find_by(email: value)
      return record.id if record
      # Try to find by username
      record = associated_model.find_by(username: value)
      return record.id if record
      # Try case-insensitive email search
      record = associated_model.where("email ILIKE ?", value).first
      return record.id if record
      # Try case-insensitive username search
      record = associated_model.where("username ILIKE ?", value).first
      return record.id if record
    end

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

    # Model-specific unique identifiers
    if @model_class == Organization
      # Organization: subdomain is unique
      if attributes["subdomain"].present?
        find_by["subdomain"] = attributes["subdomain"]
      end
    elsif @model_class == User
      # User: email is unique, username is also unique
      if attributes["email"].present?
        find_by["email"] = attributes["email"]
      elsif attributes["username"].present?
        find_by["username"] = attributes["username"]
      end
    else
      # Generic unique identifiers for other models
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
    end

    find_by
  end
end
