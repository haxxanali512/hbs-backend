# EZclaim API Service
# API Documentation: https://ezclaimapiprod.azurewebsites.net/swagger/index.html
#
# This service provides a comprehensive interface to all EZclaim API endpoints
# for Patients, Payers, Providers, Encounters, and Claims.
#
# Usage:
#   service = EzclaimService.new(organization: organization)
#   result = service.get_patients
#   result = service.create_patient(patient_data)
#   result = service.update_patient(patient_id, patient_data)
#   result = service.delete_patient(patient_id)
#
class EzclaimService
  class IntegrationError < StandardError; end
  class AuthenticationError < StandardError; end
  class NotFoundError < StandardError; end

  def initialize(organization:)
    @organization = organization
    validate_credentials!
  end

  # ===========================================================
  # PATIENTS API
  # ===========================================================

  def get_patients(params = { "Query" => "$top=1000" })
    make_request(:post, "/Patients/GetSimpleList", params: params)
  end

  def create_patient(patient_data)
    # Pass data as params so it gets wrapped correctly in the request
    make_request(:post, "/Patients", params: patient_data)
  end

  # ===========================================================
  # PROCEDURE CODES API
  # ===========================================================

  def create_procedure_code(procedure_code_data)
    # Pass data as params so it gets wrapped correctly in the request
    make_request(:post, "/Procedure_Codes", params: procedure_code_data)
  end

  # ===========================================================
  # PAYERS API
  # ===========================================================

  def get_payers(params = { "Query" => "$top=1000" })
    make_request(:post, "/Payers/GetSimpleList", params: params)
  end
  # ===========================================================
  # ENCOUNTERS API
  # ===========================================================

  def get_encounters(params = {})
    make_request(:get, "/encounters", params: params)
  end

  def get_encounter(encounter_id)
    make_request(:get, "/encounters/#{encounter_id}")
  end

  def create_encounter(encounter_data)
    make_request(:post, "/encounters", body: encounter_data)
  end

  def update_encounter(encounter_id, encounter_data)
    make_request(:put, "/encounters/#{encounter_id}", body: encounter_data)
  end

  def delete_encounter(encounter_id)
    make_request(:delete, "/encounters/#{encounter_id}")
  end

  # ===========================================================
  # CLAIMS API
  # ===========================================================

  def create_claim(claim_data)
    # Pass data as params so it gets wrapped correctly in the request
    make_request(:post, "/Claims", params: claim_data)
  end
  # ===========================================================
  # CLAIM INSUREDS API
  # ===========================================================

  def create_claim_insured(claim_insured_data)
    # Wrap payload in 'data' variable as expected by EZClaim API
    data = claim_insured_data.reject { |_k, v| v.nil? || v.to_s.empty? }
    make_request(:post, "/Claim_Insureds", params: { data: data })
  end

  # ===========================================================
  # UTILITY METHODS
  # ===========================================================

  # Check if API credentials are valid by making a test request
  def test_connection
    result = get_patients(limit: 1)
    {
      success: result[:success],
      message: result[:success] ? "Connection successful" : result[:error],
      status_code: result[:status_code]
    }
  end

  # Get API configuration
  def api_config
    settings = organization.organization_setting
    {
      api_url: settings&.ezclaim_api_url || "https://ezclaimapiprod.azurewebsites.net/api/v2",
      api_version: settings&.ezclaim_api_version || "3.0.0",
      enabled: settings&.ezclaim_enabled? || false
    }
  end

  # ===========================================================
  # LEGACY METHODS (for backward compatibility)
  # ===========================================================

  # Legacy method - use create_claim instead
  def push_claim(claim)
    payload = build_claim_payload(claim)
    result = create_claim(payload)

    if result[:success] && result[:data] && result[:data]["claim_id"]
      claim.update(external_claim_key: result[:data]["claim_id"])
      create_submission_record(claim, result)
    end

    result
  end

  private

  attr_reader :organization

  def validate_credentials!
    settings = organization.organization_setting
    raise AuthenticationError, "Organization must have EZclaim enabled" unless settings&.ezclaim_enabled?
    raise AuthenticationError, "Organization must have EZclaim API token configured" unless settings&.ezclaim_api_token.present?
  end

  def make_request(method, endpoint, params: {}, body: nil, content_type: :json)
    settings = organization.organization_setting
    api_token = settings.ezclaim_api_token
    api_url = settings.ezclaim_api_url || "https://ezclaimapiprod.azurewebsites.net/api/v2"
    api_version = settings.ezclaim_api_version || "3.0.0"

    url = "#{api_url}#{endpoint}"
    options = {
      headers: build_headers(api_token, api_version, content_type),
      timeout: 30
    }

    # Add query parameters for GET requests
    if method == :get && params.any?
      options[:query] = params
    # Add body for POST/PUT/PATCH requests
    elsif [ :post, :put, :patch ].include?(method)
      if params.any?
        # If params are provided, use them as the body (wrapped in data if needed)
        options[:body] = params.to_json
      elsif body.present?
        # If body is provided directly, use it
        if content_type == :form
          options[:body] = body
        else
          options[:body] = body.to_json
        end
      end
    end

    response = HTTParty.send(method, url, options)
    byebug
    parse_response(response)
  rescue HTTParty::Error => e
    {
      success: false,
      error: "Network error: #{e.message}",
      status_code: nil
    }
  rescue => e
    Rails.logger.error("EZclaim API error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    {
      success: false,
      error: "Unexpected error: #{e.message}",
      status_code: nil
    }
  end

  def build_headers(api_token, api_version, content_type = :json)
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "Token" => api_token,
      "Version" => api_version,
      "Cookie" => "ARRAffinity=b6bbab08004b5260938d659e633907e0f4cc0a4f6dd7d2d54cd9a3f0900e4836; ARRAffinitySameSite=b6bbab08004b5260938d659e633907e0f4cc0a4f6dd7d2d54cd9a3f0900e4836"
    }
  end

  def parse_response(response)
    # HTTParty should auto-parse JSON, but ensure it's parsed
    parsed_response = response.parsed_response || {}

    # If parsed_response is still a string, parse it manually
    if parsed_response.is_a?(String)
      begin
        parsed_response = JSON.parse(parsed_response)
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse EZClaim response: #{e.message}")
        parsed_response = {}
      end
    end

    case response.code
    when 200..299
      {
        success: true,
        data: parsed_response,
        message: parsed_response["message"] || parsed_response[:message] || "Request successful",
        status_code: response.code
      }
    when 401
      {
        success: false,
        error: "Authentication failed. Please check your API token.",
        status_code: response.code,
        data: parsed_response
      }
    when 404
      {
        success: false,
        error: "Resource not found",
        status_code: response.code,
        data: parsed_response
      }
    when 400..499
      error_message = parsed_response["error"] ||
                      parsed_response["message"] ||
                      parsed_response["errors"] ||
                      "Client error: #{response.code}"

      {
        success: false,
        error: error_message,
        errors: parsed_response["errors"],
        status_code: response.code,
        data: parsed_response
      }
    when 500..599
      {
        success: false,
        error: "Server error: #{response.code}",
        status_code: response.code,
        data: parsed_response
      }
    else
      error_message = parsed_response["error"] ||
                      parsed_response["message"] ||
                      parsed_response["errors"] ||
                      "EZclaim API error"

      {
        success: false,
        error: error_message,
        errors: parsed_response["errors"],
        status_code: response.code,
        data: parsed_response
      }
    end
  end

  # Legacy payload builder - kept for backward compatibility
  def build_claim_payload(claim)
    {
      claim_id: claim.id,
      organization_id: organization.id,
      patient: {
        first_name: claim.patient.first_name,
        last_name: claim.patient.last_name,
        dob: claim.patient.dob&.strftime("%Y-%m-%d"),
        mrn: claim.patient.mrn
      },
      provider: {
        npi: claim.provider.npi,
        name: claim.provider.full_name
      },
      date_of_service: claim.encounter.date_of_service.strftime("%Y-%m-%d"),
      place_of_service: claim.place_of_service_code,
      diagnosis_codes: claim.encounter.diagnosis_codes.map(&:code),
      claim_lines: claim.claim_lines.map do |line|
        {
          procedure_code: line.procedure_code.code,
          description: line.procedure_code.description,
          units: line.units,
          amount_billed: line.amount_billed,
          modifiers: line.modifiers,
          diagnosis_pointers: line.dx_pointers_numeric
        }
      end,
      total_billed: claim.total_billed,
      total_units: claim.total_units
    }
  end

  def create_submission_record(claim, response)
    external_key = response[:data]&.dig("claim_id") || response[:data]&.dig("external_id")

    return unless external_key

    submission = claim.claim_submissions.find_or_initialize_by(
      external_submission_key: external_key
    )

    submission.assign_attributes(
      submission_method: :api,
      status: :submitted,
      ack_status: :pending,
      submitted_at: Time.current,
      organization_id: claim.organization_id,
      patient_id: claim.patient_id
    )

    submission.save
  end
end
