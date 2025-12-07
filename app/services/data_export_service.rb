# Service for exporting data to CSV/Excel
class DataExportService
  class ExportError < StandardError; end

  # Export data for a given model with optional filters
  # Usage: DataExportService.export(model_name: "Patient", filters: { organization_id: 1 })
  def self.export(model_name:, filters: {}, format: :csv)
    service = new(model_name: model_name, filters: filters, format: format)
    service.perform
  end

  def initialize(model_name:, filters: {}, format: :csv)
    @model_name = model_name
    @filters = filters
    @format = format.to_sym
    @model_class = model_name.constantize
  end

  def perform
    validate_model!
    data = fetch_data
    headers = generate_headers
    generate_file(data, headers)
  end

  private

  attr_reader :model_name, :filters, :format, :model_class

  def validate_model!
    unless @model_class < ActiveRecord::Base
      raise ExportError, "Invalid model: #{model_name}"
    end
  end

  def fetch_data
    query = @model_class.all

    # Apply filters
    filters.each do |key, value|
      next if value.blank?

      if @model_class.column_names.include?(key.to_s)
        query = query.where(key => value)
      elsif key.to_s.end_with?("_id")
        # Handle association filters
        association_name = key.to_s.gsub("_id", "")
        if @model_class.reflect_on_association(association_name.to_sym)
          query = query.where(key => value)
        end
      end
    end

    query
  end

  def generate_headers
    # Get all column names except internal Rails columns
    excluded_columns = %w[id created_at updated_at discarded_at]
    columns = @model_class.column_names.reject { |col| excluded_columns.include?(col) }

    # Add association names for foreign keys
    headers = columns.map do |col|
      if col.end_with?("_id")
        association_name = col.gsub("_id", "")
        association = @model_class.reflect_on_association(association_name.to_sym)
        if association
          # Use the association's display name if available
          associated_model = association.class_name.constantize
          if associated_model.respond_to?(:display_name_column)
            "#{association_name}_#{associated_model.display_name_column}"
          else
            "#{association_name}_name"
          end
        else
          col
        end
      else
        col
      end
    end

    headers
  end

  def generate_file(data, headers)
    require "csv"

    case format
    when :csv
      generate_csv(data, headers)
    when :xlsx
      generate_xlsx(data, headers)
    else
      raise ExportError, "Unsupported format: #{format}"
    end
  end

  def generate_csv(data, headers)
    csv_content = CSV.generate(headers: true) do |csv|
      csv << headers

      data.find_each do |record|
        row = headers.map do |header|
          extract_value(record, header)
        end
        csv << row
      end
    end

    {
      content: csv_content,
      filename: "#{model_name.downcase}_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
      content_type: "text/csv"
    }
  end

  def generate_xlsx(data, headers)
    # For now, generate CSV and suggest using CSV format
    # Excel generation requires additional gems (axlsx, write_xlsx, etc.)
    # We'll use CSV format for Excel compatibility
    csv_content = generate_csv(data, headers)[:content]

    {
      content: csv_content,
      filename: "#{model_name.downcase}_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
      content_type: "text/csv"
    }
  end

  def extract_value(record, header)
    # Handle association lookups (e.g., "organization_name")
    if header.include?("_name") && !record.respond_to?(header)
      association_name = header.split("_name").first
      association = record.send(association_name) if record.respond_to?(association_name)

      if association
        if association.respond_to?(:name)
          association.name
        elsif association.respond_to?(:full_name)
          association.full_name
        else
          association.to_s
        end
      else
        nil
      end
    # Handle enum values
    elsif record.class.defined_enums.key?(header)
      record.send(header)&.humanize
    # Handle dates
    elsif record.class.columns_hash[header]&.type == :date || record.class.columns_hash[header]&.type == :datetime
      value = record.send(header)
      value&.strftime("%Y-%m-%d")
    # Handle JSON columns
    elsif record.class.columns_hash[header]&.type == :jsonb
      record.send(header)&.to_json
    # Regular attributes
    else
      record.send(header) rescue nil
    end
  end
end
