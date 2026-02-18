# Fetches patients from Xano patient_pull_data API, finds Organization by name,
# and creates or skips Patient records (idempotent by external_id).
#
# API response: array (or single object) with:
#   id, First_Name, Last_Name, Date_of_Birth, Gender, Address, full_name, flagged,
#   _patient_org_intermediary_of_patient._organization.Organization_Name
#
class XanoPatientPullService
  class Error < StandardError; end

  DEFAULT_URL = "https://xhnq-ezxv-7zvm.n7d.xano.io/api:AmT5eNEe:v2/patient_pull_data".freeze

  def initialize(api_url: nil)
    @api_url = api_url.presence || ENV.fetch("XANO_PATIENT_PULL_URL", DEFAULT_URL)
  end

  def call
    Rails.logger.info "[XanoPatientPull] Starting fetch from #{@api_url}"
    response_body = fetch_from_xano
    data = parse_response(response_body)
    items = Array(data)
    Rails.logger.info "[XanoPatientPull] Fetched #{items.size} record(s)"

    created = 0
    skipped = 0
    errors = []

    items.each_with_index do |payload, idx|
      result = import_one(payload)
      case result[:status]
      when :created
        created += 1
        Rails.logger.info "[XanoPatientPull] [#{idx + 1}/#{items.size}] Created: #{result[:patient_name]} (org: #{result[:org_name]})"
      when :skipped
        skipped += 1
        Rails.logger.info "[XanoPatientPull] [#{idx + 1}/#{items.size}] Skipped (existing): #{result[:patient_name]}"
      when :error
        errors << result[:error]
        Rails.logger.warn "[XanoPatientPull] [#{idx + 1}/#{items.size}] Error: #{result[:error]}"
      end
    end

    Rails.logger.info "[XanoPatientPull] Completed: created=#{created} skipped=#{skipped} errors=#{errors.size} total=#{items.size}"
    Rails.logger.warn "[XanoPatientPull] Errors: #{errors.join('; ')}" if errors.any?

    { created: created, skipped: skipped, errors: errors }
  end

  private

  def fetch_from_xano
    uri = URI(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 15
    http.read_timeout = 60
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    raise Error, "Xano API returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  end

  def parse_response(response_body)
    JSON.parse(response_body)
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON from Xano: #{e.message}"
  end

  def import_one(payload)
    org_payload = payload.dig("_patient_org_intermediary_of_patient", "_organization")
    organization = resolve_organization(org_payload)
    unless organization
      org_name = org_payload&.dig("Organization_Name").to_s.presence || "unknown"
      return { status: :error, error: "Organization not found: #{org_name} (xano_id=#{payload['id']})" }
    end

    existing = find_existing_patient(organization, payload)
    if existing
      return { status: :skipped, patient_name: "#{payload['First_Name']} #{payload['Last_Name']}".strip }
    end

    patient = build_patient(organization, payload)
    unless patient.save
      return { status: :error, error: "Patient save failed: #{patient.errors.full_messages.join(', ')} (xano_id=#{payload['id']})" }
    end

    { status: :created, patient_name: patient.full_name, org_name: organization.name }
  rescue => e
    Rails.logger.error "[XanoPatientPull] #{e.message}"
    { status: :error, error: "#{e.message} (xano_id=#{payload['id']})" }
  end

  def find_existing_patient(organization, payload)
    external_id = payload["id"].to_s.presence
    if external_id.present?
      existing = organization.patients.kept.find_by(external_id: external_id)
      return existing if existing
    end

    first_name = payload["First_Name"].to_s.strip.presence
    last_name = payload["Last_Name"].to_s.strip.presence
    dob = parse_date(payload["Date_of_Birth"])
    return nil if first_name.blank? || last_name.blank?

    organization.patients.kept.find_by(
      first_name: first_name,
      last_name: last_name,
      dob: dob
    )
  end

  def resolve_organization(org_payload)
    return nil unless org_payload.is_a?(Hash)

    name = org_payload["Organization_Name"].to_s.strip
    return nil if name.blank?

    Organization.kept.find_by("LOWER(TRIM(name)) = ?", name.downcase)
  end

  def build_patient(organization, payload)
    attrs = {
      organization_id: organization.id,
      first_name: payload["First_Name"].to_s.strip.presence || "Unknown",
      last_name: payload["Last_Name"].to_s.strip.presence || "Unknown",
      dob: parse_date(payload["Date_of_Birth"]),
      sex_at_birth: normalize_gender(payload["Gender"]),
      external_id: payload["id"].to_s.presence
    }

    address_str = payload["Address"].to_s.strip
    if address_str.present?
      parsed = parse_address(address_str)
      attrs[:address_line_1] = parsed[:address_line_1]
      attrs[:city] = parsed[:city]
      attrs[:state] = parsed[:state]
      attrs[:postal] = parsed[:postal]
    else
      attrs[:address_line_1] = "Imported (no address)"
    end

    organization.patients.build(attrs)
  end

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str.to_s)
  rescue ArgumentError
    nil
  end

  def normalize_gender(val)
    v = val.to_s.strip
    return nil if v.blank?
    return "male" if v.downcase.in?(%w[male m])
    return "female" if v.downcase.in?(%w[female f])
    v
  end

  # "207 Orchid Rd Levittown NY, 11767" -> address_line_1, city, state, postal
  def parse_address(full)
    full = full.to_s.strip
    if full.match?(/\s+[A-Z]{2},?\s+\d{5}(-\d{4})?\s*$/i)
      # ... City ST, 12345 or ... City ST 12345
      m = full.match(/\A(.+?)\s+([A-Za-z\s]+?)\s+([A-Z]{2}),?\s*(\d{5}(?:-\d{4})?)\s*\z/i)
      if m
        return {
          address_line_1: m[1].strip,
          city: m[2].strip,
          state: m[3].upcase,
          postal: m[4]
        }
      end
    end
    { address_line_1: full, city: nil, state: nil, postal: nil }
  end
end
