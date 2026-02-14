class OrganizationSetting < ApplicationRecord
  audited

  DEFAULT_TIME_ZONE = "America/New_York"

  belongs_to :organization

  # US time zones for dropdown: [ [ "Eastern Time (US & Canada)", "America/New_York" ], ... ]
  def self.us_time_zone_options
    ActiveSupport::TimeZone.us_zones.map { |z| [ z.to_s, z.tzinfo.name ] }
  end

  def effective_time_zone
    time_zone.presence || DEFAULT_TIME_ZONE
  end

  # Validations
  validates :mrn_format, format: { with: /\A\{prefix\}\{sequence\}\z|\A\{sequence\}\z/i }, allow_blank: true, unless: :mrn_disabled?
  validates :mrn_sequence, numericality: { only_integer: true, greater_than: 0 }, allow_blank: true, unless: :mrn_disabled?

  # Scopes
  scope :with_mrn_enabled, -> { where(mrn_enabled: true) }
  scope :with_mrn_disabled, -> { where(mrn_enabled: false) }

  # Instance Methods
  def mrn_enabled?
    mrn_enabled == true
  end

  def mrn_disabled?
    !mrn_enabled?
  end

  def generate_mrn
    return nil unless mrn_enabled?

    prefix = mrn_prefix.present? ? mrn_prefix : ""
    sequence = next_sequence_number

    if mrn_format.present?
      mrn_format.gsub("{prefix}", prefix).gsub("{sequence}", sequence.to_s.rjust(5, "0"))
    elsif prefix.present?
      "#{prefix}#{sequence.to_s.rjust(5, '0')}"
    else
      sequence.to_s.rjust(8, "0")
    end
  end

  def next_sequence_number
    return mrn_sequence.to_i unless mrn_sequence.to_i.positive?

    # Find the highest existing MRN sequence for this org
    existing_max = organization.patients.where("mrn ~ ?", "^#{mrn_prefix || ''}").pluck(:mrn).map do |mrn|
      mrn.gsub(mrn_prefix.to_s, "").to_i
    end.max || 0

    [ mrn_sequence.to_i, existing_max + 1 ].max
  end

  def ezclaim_enabled?
    ezclaim_enabled == true
  end

  def ezclaim_configured?
    ezclaim_enabled? && ezclaim_api_token.present?
  end
end
