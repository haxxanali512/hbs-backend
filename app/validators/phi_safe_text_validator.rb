class PhiSafeTextValidator
  ERROR_CODE = "ST_PHI_DETECTED"
  PATTERNS = [
    /\bssn\b/i,
    /\bsocial\s+security\b/i,
    /\bdob\b/i,
    /\bmrn\b/i,
    /\bmedical\s+record\b/i,
    /\bpatient\s+name\b/i,
    /\b\d{3}-\d{2}-\d{4}\b/,
    /\b\d{2}\/\d{2}\/\d{4}\b/
  ].freeze

  def self.ensure_safe!(record, attribute, value)
    return if value.blank?

    if PATTERNS.any? { |pattern| value.match?(pattern) }
      record.errors.add(attribute, "[#{ERROR_CODE}] Detected possible PHI in text.")
    end
  end
end
