# Builds a Fuse SubmitCheckRequest from app models and submits via FuseApiService.
# All Fuse API calls go through FuseApiService; this service only builds the payload and updates the payer.
#
# Usage:
#   result = FuseEligibilitySubmitService.submit(encounter: encounter, check_id: "payer-123")
#   # => Fuse API response; payer.fuse_eligibility_check_id is set from response["checkId"]
class FuseEligibilitySubmitService
  class Error < StandardError; end

  def self.submit(encounter:, check_id: nil)
    new(encounter: encounter, check_id: check_id).submit
  end

  def initialize(encounter:, check_id: nil)
    @encounter = encounter
    @check_id = check_id
  end

  def submit
    payload = build_payload
    response = fuse_api.submit_check(payload: payload, check_id: @check_id)
    update_payer_check_id(response)
    response
  end

  private

  def fuse_api
    @fuse_api ||= FuseApiService.new
  end

  def build_payload
    {
      "checkDetails" => {
        "patient" => build_patient_info,
        "subscriber" => build_subscriber_info,
        "payer" => build_payer_info,
        "provider" => build_provider_info,
        "encounter" => build_encounter_info
      }
    }
  end

  def build_patient_info
    p = @encounter.patient
    raise Error, "Encounter has no patient" unless p
    {
      "firstName" => p.first_name.to_s,
      "lastName" => p.last_name.to_s,
      "dateOfBirth" => p.dob&.strftime("%Y-%m-%d").to_s,
      "relationship" => relationship_for_subscriber
    }.compact
  end

  def build_subscriber_info
    cov = @encounter.patient_insurance_coverage
    raise Error, "Encounter has no patient_insurance_coverage" unless cov
    {
      "memberId" => cov.member_id.to_s,
      "firstName" => subscriber_first_name(cov),
      "lastName" => subscriber_last_name(cov),
      "dateOfBirth" => nil
    }.compact_blank
  end

  def build_payer_info
    payer = payer_from_encounter
    raise Error, "Payer not found for encounter" unless payer
    {
      "payerId" => (payer.national_payer_id || payer.hbs_payer_key).to_s,
      "name" => payer.name.to_s,
      "phoneNumber" => payer.support_phone.presence
    }.compact
  end

  def build_provider_info
    prov = @encounter.provider
    org = @encounter.organization
    loc = billing_location(org)
    ident = org&.organization_identifier
    pos_code = @encounter.place_of_service_code.presence || @encounter.organization_location&.place_of_service_code || "11"
    {
      "npi" => (prov&.npi || loc&.billing_npi).to_s,
      "billingAddress" => format_billing_address(loc),
      "taxId" => ident&.tax_identification_number.to_s,
      "placeOfService" => { "code" => pos_code.to_s.rjust(2, "0"), "label" => place_of_service_label(pos_code) },
      "organizationName" => org&.name.presence
    }.compact
  end

  def build_encounter_info
    codes = @encounter.all_procedure_codes.map(&:code).compact
    {
      "serviceTypeCodes" => service_type_codes,
      "procedureCodes" => codes.any? ? codes : [ "99213" ],
      "additionalQuestions" => []
    }
  end

  def relationship_for_subscriber
    cov = @encounter.patient_insurance_coverage
    return nil unless cov
    case cov.relationship_to_subscriber
    when "self" then "SELF"
    else "DEPENDENT"
    end
  end

  def subscriber_first_name(cov)
    return nil if cov.subscriber_name.blank?
    cov.subscriber_name.split(/\s+/, 2).first
  end

  def subscriber_last_name(cov)
    return nil if cov.subscriber_name.blank?
    cov.subscriber_name.split(/\s+/, 2).second || cov.subscriber_name
  end

  def payer_from_encounter
    @encounter.patient_insurance_coverage&.insurance_plan&.payer
  end

  def billing_location(org)
    return nil unless org
    org.organization_locations.billing.active.first || @encounter.organization_location
  end

  def format_billing_address(loc)
    return "" unless loc
    parts = [ loc.address_line_1, loc.address_line_2, loc.city, loc.state, loc.postal_code ].compact_blank
    parts.join(", ")
  end

  def place_of_service_label(code)
    { "10" => "Telehealth", "11" => "Office", "12" => "Patient's Home" }.fetch(code.to_s, "Office")
  end

  def service_type_codes
    # X12 service type codes; 98 = Professional (Physician) Visit - Office
    [ "98" ]
  end

  def update_payer_check_id(response)
    check_id = response["checkId"]
    return if check_id.blank?
    payer = payer_from_encounter
    payer&.update!(fuse_eligibility_check_id: check_id)
  end
end
