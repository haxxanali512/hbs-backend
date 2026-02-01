# Builds Fuse SubmitCheckRequest from form params (no Patient/Encounter in DB) and submits via FuseApiService.
# Real-time: after submit, call get_check to fetch current status/result.
#
# Usage:
#   result = FuseEligibilityCheckFromParamsService.submit(organization:, user:, params: params)
#   # => { response: fuse_api_response, check_result: get_check_result or nil }
class FuseEligibilityCheckFromParamsService
  class Error < StandardError; end

  def self.submit(organization:, user:, params:)
    new(organization: organization, user: user, params: params).submit
  end

  def initialize(organization:, user:, params:)
    @organization = organization
    @user = user
    @params = params
  end

  def submit
    payload = build_payload
    check_id = @params[:check_id].presence || "fuse-#{@organization.id}-#{SecureRandom.hex(8)}"
    response = fuse_api.submit_check(payload: payload, check_id: check_id)
    check_id_from_response = response["checkId"]
    # Optionally fetch result once (real-time)
    check_result = fetch_check_result(check_id_from_response) if check_id_from_response.present?
    { response: response, check_id: check_id_from_response, check_result: check_result }
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
    {
      "firstName" => @params[:patient_first_name].to_s,
      "lastName" => @params[:patient_last_name].to_s,
      "dateOfBirth" => normalize_date(@params[:patient_date_of_birth]),
      "relationship" => @params[:patient_relationship].presence
    }.compact
  end

  def build_subscriber_info
    {
      "memberId" => @params[:subscriber_member_id].to_s,
      "firstName" => @params[:subscriber_first_name].presence,
      "lastName" => @params[:subscriber_last_name].presence,
      "dateOfBirth" => normalize_date(@params[:subscriber_date_of_birth]).presence
    }.compact_blank
  end

  def build_payer_info
    payer = Payer.find_by(id: @params[:payer_id])
    raise Error, "Payer not found" unless payer
    {
      "payerId" => (payer.national_payer_id || payer.hbs_payer_key).to_s,
      "name" => payer.name.to_s,
      "phoneNumber" => payer.support_phone.presence
    }.compact
  end

  def build_provider_info
    provider = @organization.providers.kept.find_by(id: @params[:provider_id])
    raise Error, "Provider not found" unless provider
    loc = @organization.organization_locations.billing.active.first
    ident = @organization.organization_identifier
    pos_code = @params[:place_of_service_code].presence || "11"
    {
      "npi" => (provider.npi || loc&.billing_npi).to_s,
      "billingAddress" => format_billing_address(loc),
      "taxId" => ident&.tax_identification_number.to_s,
      "placeOfService" => { "code" => pos_code.to_s.rjust(2, "0"), "label" => place_of_service_label(pos_code) },
      "organizationName" => @organization.name.presence
    }.compact
  end

  def build_encounter_info
    procedure_codes = Array(@params[:procedure_code_ids]).reject(&:blank?)
    codes = procedure_codes.any? ? ProcedureCode.where(id: procedure_codes).pluck(:code) : [ "99213" ]
    {
      "serviceTypeCodes" => [ "98" ],
      "procedureCodes" => codes,
      "additionalQuestions" => []
    }
  end

  def normalize_date(val)
    return nil if val.blank?
    Date.parse(val.to_s).strftime("%Y-%m-%d")
  rescue ArgumentError
    nil
  end

  def format_billing_address(loc)
    return "" unless loc
    parts = [ loc.address_line_1, loc.address_line_2, loc.city, loc.state, loc.postal_code ].compact_blank
    parts.join(", ")
  end

  def place_of_service_label(code)
    { "10" => "Telehealth", "11" => "Office", "12" => "Patient's Home" }.fetch(code.to_s, "Office")
  end

  def fetch_check_result(check_id)
    fuse_api.get_check(check_id: check_id)
  rescue FuseApiService::Error
    nil
  end
end
