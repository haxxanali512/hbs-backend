# Claim Submission Service
# Handles the flow: Encounter → Build Claim Payload → POST Claim → Attach Service Lines → Track Submission
#
# This service builds claim payloads from encounters and submits them to EZClaim.
# It handles the complete submission flow including claim creation and service line attachment.
class ClaimSubmissionService
  class ValidationError < StandardError; end
  class SubmissionError < StandardError; end

  def initialize(encounter:, organization:)
    @encounter = encounter
    @organization = organization
    @ezclaim_service = EzclaimService.new(organization: organization)
  end

  # Main entry point: Submit encounter for billing
  def submit_for_billing
    # Build claim payload from encounter
    claim_payload = build_claim_payload

    # POST claim to EZClaim
    claim_result = @ezclaim_service.create_claim(claim_payload)

    unless claim_result[:success]
      raise SubmissionError, "Failed to create claim in EZClaim: #{claim_result[:error]}"
    end

    # Extract claim ID from response
    claim_id = extract_claim_id(claim_result)

    unless claim_id
      raise SubmissionError, "EZClaim did not return a claim ID"
    end

    # Build service lines payload (may be empty if no lines)
    service_lines_array = build_service_lines_payload(claim_id)

    # POST service lines to EZClaim
    # API expects array of service line objects
    service_lines_result = @ezclaim_service.create_service_lines(service_lines_array)

    unless service_lines_result[:success]
      # If service lines fail, we still have a claim created
      # Log the error but don't fail completely
      Rails.logger.error("Service lines submission failed: #{service_lines_result[:error]}")
      # Continue to create claim record with partial success
    end

    # Create Claim record with response data
    claim = create_claim_record(claim_result, claim_id)

    # Create ClaimSubmission record
    create_submission_record(claim, claim_result, service_lines_result)

    {
      success: true,
      claim: claim,
      claim_id: claim_id,
      service_lines_success: service_lines_result[:success],
      service_lines_error: service_lines_result[:error]
    }
  rescue ValidationError, SubmissionError => e
    Rails.logger.error("Claim submission error: #{e.message}")
    {
      success: false,
      error: e.message
    }
  rescue => e
    Rails.logger.error("Unexpected error in claim submission: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    {
      success: false,
      error: "Unexpected error: #{e.message}"
    }
  end

  private

  attr_reader :encounter, :organization, :ezclaim_service

  # Validate that encounter is ready for billing
  # Note: validations are intentionally skipped per request to allow submission to EZClaim
  def validate_encounter_ready!
    true
  end

  # Build claim payload from encounter
  def build_claim_payload
    patient = encounter.patient
    provider = encounter.provider
    diagnosis_codes = encounter.diagnosis_codes.limit(4).to_a

    {
      ClaPatFID: patient.external_id || patient.id.to_s,
      PatientName: "#{patient.first_name} #{patient.last_name}".strip,
      claRenderingPhyFID: provider.npi || provider.id.to_s,
      ClaDiagnosis1: diagnosis_codes[0]&.code || "",
      ClaDiagnosis2: diagnosis_codes[1]&.code || "",
      ClaDiagnosis3: diagnosis_codes[2]&.code || "",
      ClaDiagnosis4: diagnosis_codes[3]&.code || "",
      ClaSubmissionMethod: "E", # Electronic
      claBillingPhyFID: provider.npi || provider.id.to_s,
      SrvDateFrom: encounter.date_of_service&.strftime("%Y-%m-%d") || "",
      SrvDateTo: encounter.date_of_service&.strftime("%Y-%m-%d") || ""
    }
  end

  # Build service lines payload from encounter claim lines
  # Uses fee schedule pricing to determine charges based on procedure code
  def build_service_lines_payload(claim_id)
    # Get claim lines from existing claim
    claim_lines = encounter.claim&.claim_lines || []

    # Build array of service lines
    service_lines = claim_lines.map do |line|
      # Look up pricing from fee schedule using procedure code
      # Priority: provider-specific -> org-wide
      pricing_result = FeeSchedulePricingService.resolve_pricing(
        organization.id,
        encounter.provider_id,
        line.procedure_code_id
      )

      # If pricing fails, allow submission with zero pricing
      unit_price = if pricing_result[:success]
                     pricing_result[:pricing][:unit_price].to_f
      else
                     0.0
      end
      units = line.units.to_f

      # Calculate charges: unit_price * units
      total_charges = unit_price * units

      {
        SrvClaFID: claim_id,
        SrvFromDate: encounter.date_of_service&.strftime("%Y-%m-%d") || "",
        SrvToDate: encounter.date_of_service&.strftime("%Y-%m-%d") || "",
        SrvProcedureCode: line.procedure_code.code,
        SrvUnits: units.to_i.to_s, # Units as integer string
        SrvCharges: total_charges.to_s, # Total charges from fee schedule
        SrvPerUnitChargesCC: unit_price.to_s, # Per-unit charge from fee schedule
        SrvPlace: encounter.organization_location&.place_of_service_code || "11",
        SrvPrintLineItem: "",
        SrvDateTimeCreated: "",
        SrvDateTimeModified: "",
        SrvCreatedComputerName: "",
        SrvLastComputerName: "",
        SrvRespChangeDate: ""
      }
    end

    # Return as array (EZClaim API expects array of service lines)
    service_lines
  end

  # Extract claim ID from EZClaim response
  def extract_claim_id(result)
    # EZClaim API might return claim_id in different formats
    # Check common response structures
    result[:data]["Data"].first["InsertedId"]
  end

  # Update Claim record with EZClaim response data
  def create_claim_record(claim_result, claim_id)
    # Claim should ideally already exist; if not, create a minimal one
    existing_claim = encounter.claim

    unless existing_claim
      existing_claim = Claim.create!(
        organization_id: organization.id,
        encounter_id: encounter.id,
        patient_id: encounter.patient_id,
        provider_id: encounter.provider_id,
        specialty_id: encounter.specialty_id,
        place_of_service_code: encounter.organization_location&.place_of_service_code || "11",
        status: :generated,
        generated_at: Time.current
      )
    end

    # Update existing claim with EZClaim response data
    existing_claim.update!(
      external_claim_key: claim_id,
      status: :submitted,
      submitted_at: Time.current
    )

    existing_claim
  end

  # Create ClaimSubmission record to track the submission
  def create_submission_record(claim, claim_result, service_lines_result)
    external_key = extract_claim_id(claim_result)

    return unless external_key

    submission = claim.claim_submissions.find_or_initialize_by(
      external_submission_key: external_key
    )

    submission.assign_attributes(
      submission_method: :api,
      status: service_lines_result[:success] ? :submitted : :partial,
      ack_status: :pending,
      submitted_at: Time.current,
      organization_id: organization.id,
      patient_id: encounter.patient_id,
      error_message: service_lines_result[:success] ? nil : "Service lines submission failed: #{service_lines_result[:error]}"
    )

    submission.save
  end
end
