# EZclaim API Integration Service (Legacy)
# API Documentation: https://ezclaimapiprod.azurewebsites.net/swagger/index.html
#
# DEPRECATED: This service is kept for backward compatibility.
# Please use EzclaimService for new implementations.
#
# Before using:
# 1. Review Swagger docs to confirm endpoint paths, authentication, and payload format
# 2. Configure API credentials in Rails credentials or Organization settings
# 3. Update build_ezclaim_payload to match EZclaim's expected format
# 4. Adjust send_to_ezclaim headers and endpoint path as needed
#
class EzclaimIntegrationService
  class IntegrationError < StandardError; end

  def initialize(claim:, organization:)
    @claim = claim
    @organization = organization
  end

  def push_claim
    validate_claim!

    # Build EZclaim payload from claim
    payload = build_ezclaim_payload

    # Make API call to EZclaim
    response = send_to_ezclaim(payload)

    # Update claim with external key if provided
    if response[:success] && response[:external_key].present?
      @claim.update(external_claim_key: response[:external_key])

      # Create/update submission record
      create_submission_record(response)
    end

    response
  rescue => e
    Rails.logger.error("EZclaim integration error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { success: false, error: e.message }
  end

  private

  attr_reader :claim, :organization

  def validate_claim!
    raise IntegrationError, "Claim must be validated before pushing to EZclaim" unless claim.validated? || claim.submitted?
    raise IntegrationError, "Claim must have at least one claim line" unless claim.claim_lines.any?
    raise IntegrationError, "Organization must have EZclaim credentials configured" unless has_ezclaim_credentials?
  end

  def has_ezclaim_credentials?
    # Check if organization has EZclaim API credentials
    # Token is stored in organization_setting
    settings = organization.organization_setting
    return false unless settings
    settings.ezclaim_enabled? && settings.ezclaim_api_token.present?
  end

  def build_ezclaim_payload
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

  def send_to_ezclaim(payload)
    # Get API credentials from organization_setting
    settings = organization.organization_setting
    api_token = settings&.ezclaim_api_token
    api_url = settings&.ezclaim_api_url || "https://ezclaimapiprod.azurewebsites.net/api/v2"
    api_version = settings&.ezclaim_api_version || "3.0.0"

    # Make HTTP request with EZclaim required headers
    response = HTTParty.post(
      "#{api_url}/claims",
      headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Token" => api_token,
        "Version" => api_version
      },
      body: payload.to_json,
      timeout: 30
    )

    if response.success?
      {
        success: true,
        external_key: response.parsed_response["claim_id"] || response.parsed_response["external_id"],
        message: "Claim successfully pushed to EZclaim",
        ezclaim_response: response.parsed_response
      }
    else
      {
        success: false,
        error: response.parsed_response["error"] || response.parsed_response["message"] || "EZclaim API error",
        status_code: response.code,
        ezclaim_response: response.parsed_response
      }
    end
  rescue HTTParty::Error => e
    {
      success: false,
      error: "Network error: #{e.message}"
    }
  rescue => e
    {
      success: false,
      error: "Unexpected error: #{e.message}"
    }
  end

  def create_submission_record(response)
    submission = claim.claim_submissions.find_or_initialize_by(
      external_submission_key: response[:external_key]
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
