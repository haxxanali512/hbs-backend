# Temporary service: fetch prescriptions from Xano API, create Prescription records,
# and download Prescription_Image to attach via Active Storage (S3/local).
#
# Xano → Our Prescription model mapping:
#   Written_Date           → date_written
#   expiration_date        → expires_on
#   Active_Prescription   → expired = !Active_Prescription
#   procedure.Code        → procedure_code (find by code)
#   procedure.Description → used in title
#   patient               → find or create Patient (First_Name, Last_Name, Date_of_Birth, Gender)
#   organization          → find our Organization by Organization_Name or Organization_NPI (fallback: form org)
#   diagnosis_code_id[]   → array of { Code, Description }; match our DiagnosisCode by Code
#   Prescription_Image.url → download and attach to prescription.documents
#
class XanoPrescriptionImportService
  class Error < StandardError; end

  def initialize(api_url: nil)
    @api_url = api_url.presence || ENV.fetch("XANO_PRESCRIPTIONS_API_URL", "")
  end

  def call
    raise Error, "XANO_PRESCRIPTIONS_API_URL is not set" if @api_url.blank?

    response = fetch_from_xano
    data = parse_response(response)
    items = data.is_a?(Array) ? data : (data.is_a?(Hash) && data["prescriptions"] ? data["prescriptions"] : [ data ].compact)
    created = 0
    errors = []

    items.each do |payload|
      result = import_one(payload)
      if result[:created]
        created += 1
      elsif result[:error]
        errors << result[:error]
      end
    end

    Rails.logger.info "[XanoPrescriptionImport] Completed: created=#{created} errors=#{errors.size} total_items=#{items.size}"
    Rails.logger.warn "[XanoPrescriptionImport] Errors: #{errors.join('; ')}" if errors.any?

    { created: created, errors: errors }
  end

  private

  def fetch_from_xano
    uri = URI(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
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
    organization = resolve_organization(payload["organization"])
    return { created: false, error: "Organization not found for this record (match by Organization_Name or Organization_NPI)" } unless organization

    patient = find_or_create_patient(organization, payload["patient"])
    return { created: false, error: "Patient not found/created" } unless patient

    procedure = payload["procedure"]
    procedure_code = procedure_code_from(procedure)
    return { created: false, error: "Procedure code not found for #{procedure&.dig('Code')}" } unless procedure_code

    specialty = specialty_for(procedure_code)
    return { created: false, error: "No specialty for procedure #{procedure_code.code}" } unless specialty

    date_written = parse_date(payload["Written_Date"])
    expires_on = parse_date(payload["expiration_date"])
    return { created: false, error: "Invalid dates" } unless date_written && expires_on

    title = build_title(procedure, date_written)
    expired = payload["Active_Prescription"] == false

    diagnosis_code_ids = resolve_diagnosis_code_ids(payload["diagnosis_code_id"])

    prescription = organization.prescriptions.build(
      patient_id: patient.id,
      organization_id: organization.id,
      date_written: date_written,
      expires_on: expires_on,
      expired: expired,
      title: title,
      procedure_code_id: procedure_code.id,
      specialty_id: specialty.id,
      provider_id: nil,
      archived: false
    )
    prescription.expiration_option = "date"
    prescription.expiration_date = expires_on.to_s
    prescription.diagnosis_code_ids = diagnosis_code_ids

    unless prescription.save
      return { created: false, error: prescription.errors.full_messages.join(", ") }
    end

    attach_image(prescription, payload["Prescription_Image"])

    Rails.logger.info "[XanoPrescriptionImport] Added prescription id=#{prescription.id} org=#{organization.name} (id=#{organization.id}) patient=#{patient.first_name} #{patient.last_name} (id=#{patient.id}) procedure=#{procedure_code.code} date_written=#{date_written} xano_id=#{payload['id']}"
    { created: true }
  rescue => e
    Rails.logger.error "XanoPrescriptionImportService: #{e.message}"
    { created: false, error: e.message }
  end

  def resolve_organization(org_payload)
    return nil unless org_payload.is_a?(Hash)

    name = org_payload["Organization_Name"].to_s.strip
    npi = org_payload["Organization_NPI"].to_s.presence
    found = Organization.kept.find_by("LOWER(TRIM(name)) = ?", name.downcase) if name.present?
    found ||= Organization.kept.joins(:organization_identifier).where(organization_identifiers: { npi: npi }).first if npi.present?
    found
  end

  def resolve_diagnosis_code_ids(diagnosis_code_id_payload)
    return [] if diagnosis_code_id_payload.blank?

    ids = []
    list = diagnosis_code_id_payload.is_a?(Array) ? diagnosis_code_id_payload : [ diagnosis_code_id_payload ]
    list.each do |item|
      code = item.is_a?(Hash) ? item["Code"].to_s.strip : item.to_s.strip
      next if code.blank?
      dc = DiagnosisCode.active.find_by(code: code)
      ids << dc.id if dc
    end
    ids.uniq
  end

  def find_or_create_patient(organization, patient_payload)
    return nil unless patient_payload.is_a?(Hash)

    first_name = patient_payload["First_Name"].to_s.strip
    last_name = patient_payload["Last_Name"].to_s.strip
    dob_str = patient_payload["Date_of_Birth"].to_s.strip
    return nil if first_name.blank? && last_name.blank?

    dob = parse_date(dob_str)
    existing = organization.patients.kept.find_by(
      first_name: first_name,
      last_name: last_name,
      dob: dob
    )
    return existing if existing

    organization.patients.create!(
      first_name: first_name,
      last_name: last_name,
      dob: dob || Date.current,
      sex_at_birth: patient_payload["Gender"].to_s.presence
    )
  end

  def procedure_code_from(procedure)
    return nil unless procedure.is_a?(Hash)
    code = procedure["Code"].to_s.strip
    return nil if code.blank?

    ProcedureCode.active.find_by(code: code)
  end

  def specialty_for(procedure_code)
    procedure_code.specialties.active.first || Specialty.active.first
  end

  def parse_date(str)
    return nil if str.blank?
    Date.parse(str.to_s)
  rescue ArgumentError
    nil
  end

  def build_title(procedure, date_written)
    desc = procedure.is_a?(Hash) ? procedure["Description"].to_s : "Prescription"
    "Prescription - #{desc.presence || 'Unknown'} - #{date_written}"
  end

  def attach_image(prescription, image_payload)
    return unless image_payload.is_a?(Hash) && image_payload["url"].present?

    url = image_payload["url"]
    name = image_payload["name"].presence || File.basename(URI.parse(url).path) rescue "prescription.pdf"
    uri = URI(url)
    io = nil
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      raise "Failed to download image: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      io = StringIO.new(response.body)
    end
    prescription.documents.attach(io: io, filename: name)
  rescue => e
    Rails.logger.warn "Could not attach Prescription_Image for prescription #{prescription.id}: #{e.message}"
  end
end
