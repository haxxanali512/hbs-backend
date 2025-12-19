class ProcedureCodeRule < ApplicationRecord
  belongs_to :procedure_code

  validates :procedure_code_id, uniqueness: true
  validates :pricing_type, inclusion: { in: %w[per_unit per_procedure] }, allow_nil: true

  # Convenience accessor for editing special rules as text in the admin UI
  # One rule per line; persisted as an array in special_rules JSONB
  def special_rules_text
    parse_special_rules.join("\n")
  end

  def special_rules_text=(value)
    self.special_rules = value.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
  end

  # Parse special rules from JSON array
  def parse_special_rules
    return [] unless special_rules.is_a?(Array)
    special_rules
  end

  # Check if rule requires clinical documentation
  def requires_clinical_documentation?
    parse_special_rules.any? { |rule| rule.to_s.downcase.include?("requires clinical documentation") }
  end

  # Get unit limit from rules
  def unit_limit
    parse_special_rules.each do |rule|
      if rule.to_s.match(/limit (\d+) unit/i)
        return $1.to_i
      elsif rule.to_s.match(/only (\d+) unit/i)
        return $1.to_i
      end
    end
    nil
  end

  # Get codes that cannot be billed with this code
  def cannot_be_billed_with
    codes = []
    parse_special_rules.each do |rule|
      rule_str = rule.to_s
      if rule_str.match(/cannot be billed (?:w\.|with) (.+)/i)
        codes_str = $1
        # Extract codes (can be comma-separated or "or"-separated)
        codes_str.split(/[, or]+/).each do |code|
          code = code.strip
          # Match codes like "97813", "20610", "J0655", etc.
          codes << code if code.match(/^[\dA-Z]+$/)
        end
      end
    end
    codes.uniq
  end

  # Get codes that are required for this code
  def requires_codes
    codes = []
    parse_special_rules.each do |rule|
      rule_str = rule.to_s
      # Match "Requires 97810 or 97813" or "Requires 96360" etc.
      if rule_str.match(/requires (\d+[A-Z]?(?:\s+or\s+\d+[A-Z]?)*)/i)
        codes_str = $1
        # Extract codes (can be "or"-separated or space-separated)
        codes_str.split(/\s+or\s+|\s+/).each do |code|
          code = code.strip
          # Match codes like "97810", "97813", "96360", etc.
          codes << code if code.match(/^[\dA-Z]+$/)
        end
      end
    end
    codes.uniq
  end

  # Check if units represent dosage (not time)
  def units_represent_dosage?
    parse_special_rules.any? { |rule| rule.to_s.downcase.include?("units represent dosage") }
  end

  # Check if one per diagnosis
  def one_per_diagnosis?
    parse_special_rules.any? { |rule| rule.to_s.downcase.include?("one per diagnosis") }
  end

  # Check frequency limit (e.g., "Allowed 1x per 3 months")
  def frequency_limit
    parse_special_rules.each do |rule|
      if rule.to_s.match(/allowed (\d+)x per (\d+) month/i)
        return { count: $1.to_i, months: $2.to_i }
      end
    end
    nil
  end

  # Check if new patient only
  def new_patient_only?
    parse_special_rules.any? { |rule| rule.to_s.downcase.include?("no encounters") && rule.to_s.downcase.include?("previous") }
  end

  # Get years for new patient restriction
  def new_patient_years
    parse_special_rules.each do |rule|
      if rule.to_s.match(/previous (\d+) year/i)
        return $1.to_i
      end
    end
    3 # Default to 3 years
  end
end
