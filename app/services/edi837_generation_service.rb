require "date"

class Edi837GenerationService
  # EDI 837 Professional (837P) Generation Service - HIPAA 5010 Compliant
  # Generates HIPAA-compliant X12 837P EDI files from encounters/claims
  # Follows CMS-1500 anchored, deterministic serialization

  attr_reader :encounters, :organization, :errors

  # EDI Sender and Receiver IDs (from Rails credentials, hardcoded for now)
  EDI_SENDER_ID = Rails.application.credentials.dig(:waystar, :sender_id)
  EDI_RECEIVER_ID = Rails.application.credentials.dig(:waystar, :receiver_id)

  def initialize(encounters:, organization:)
    @encounters = Array(encounters)
    @organization = organization
    @errors = []
    @transaction_count = 0
    @hl_counter = 0 # Hierarchical level counter
    @interchange_control_number = generate_interchange_control_number
    @group_control_number = generate_group_control_number
    @st_segment_count = 0 # Track number of ST segments for GE01
    @st_control_numbers = {} # Track ST control numbers for SE02 matching
  end

  def generate
    return { success: false, error: "No encounters provided" } if @encounters.empty?
    return { success: false, error: "Organization not provided" } unless @organization

    # Validate before generation
    validation_result = validate_encounters
    unless validation_result[:valid]
      return { success: false, error: "Validation failed: #{validation_result[:errors].join(', ')}" }
    end

    begin
      edi_content = build_edi_file
      filename = generate_filename

      {
        success: true,
        content: edi_content,
        filename: filename,
        transaction_count: @transaction_count
      }
    rescue => e
      Rails.logger.error "EDI 837 Generation Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  def generate_and_save_to_file(file_path = nil)
    result = generate
    return result unless result[:success]

    # In development, save to public/ directory for easy access
    # In production, use tmp/ directory
    if Rails.env.development?
      file_path ||= Rails.root.join("public", "edi_837", result[:filename])
    else
      file_path ||= Rails.root.join("tmp", "edi_837", result[:filename])
    end
    FileUtils.mkdir_p(File.dirname(file_path))

    File.write(file_path, result[:content])
    result.merge(file_path: file_path.to_s)
  end

  private

  def build_edi_file
    segments = []

    # 1. ENVELOPE - Interchange Header (ISA) - MUST
    segments << build_isa_segment

    # 2. ENVELOPE - Functional Group Header (GS) - MUST
    segments << build_gs_segment

    # Process each encounter as a separate transaction
    @encounters.each do |encounter|
      transaction_segments = []

      # 3. ENVELOPE - Transaction Set Header (ST) - MUST
      transaction_segments << build_st_segment(encounter)

      # 4. ENVELOPE - Beginning of Hierarchical Transaction (BHT) - MUST
      transaction_segments << build_bht_segment(encounter)

      # 5. SUBMITTER & RECEIVER (1000A, 1000B) - MUST
      transaction_segments.concat(build_submitter_receiver_loops)

      # 6. BILLING PROVIDER (2000A) - MUST
      transaction_segments.concat(build_billing_provider_loop(encounter))

      # 7. SUBSCRIBER (2000B) - MUST
      transaction_segments.concat(build_subscriber_loop(encounter))

      # 8. PATIENT (2000C) - MUST only when patient ≠ subscriber
      if patient_different_from_subscriber?(encounter)
        transaction_segments.concat(build_patient_loop(encounter))
      end

      # 9. CLAIM INFORMATION (2300) - MUST
      transaction_segments.concat(build_claim_loop(encounter))

      # 10. SERVICE LINES (2400) - MUST
      transaction_segments.concat(build_service_line_loops(encounter))

      # 11. ENVELOPE - Transaction Set Trailer (SE) - MUST
      transaction_segments << build_se_segment(encounter, transaction_segments.count + 1)

      # Add all transaction segments to main segments array
      segments.concat(transaction_segments)

      @transaction_count += 1
      @hl_counter = 0 # Reset for next transaction
    end

    # 12. ENVELOPE - Functional Group Trailer (GE) - MUST
    segments << build_ge_segment

    # 13. ENVELOPE - Interchange Trailer (IEA) - MUST
    segments << build_iea_segment

    segments.join("\n")
  end

  # ============================================================
  # ENVELOPE SEGMENTS (MUST)
  # ============================================================

  def build_isa_segment
    # Sender ID: Provider ID (258966)
    sender_id = edi_sender_id
    # Receiver ID: Clearinghouse (ZIRMED)
    receiver_id = edi_receiver_id
    date_str = Date.today.strftime("%y%m%d")
    time_str = Time.current.strftime("%H%M")
    interchange_control_number = generate_interchange_control_number

    [
      "ISA",
      "00", # Authorization Information Qualifier
      pad("", 10), # Authorization Information
      "00", # Security Information Qualifier
      pad("", 10), # Security Information
      "ZZ", # Interchange ID Qualifier (Sender)
      pad(sender_id, 15), # Interchange Sender ID (Provider: 258966)
      "ZZ", # Interchange ID Qualifier (Receiver)
      pad(receiver_id, 15), # Interchange Receiver ID (Clearinghouse: ZIRMED)
      date_str, # Interchange Date
      time_str, # Interchange Time
      "^", # Interchange Control Standards Identifier
      "00501", # Interchange Control Version Number
      pad(interchange_control_number, 9), # Interchange Control Number
      "0", # Acknowledgment Requested
      "P", # Usage Indicator (P=Production, T=Test)
      ":" # Component Element Separator
    ].join("*")
  end

  def build_gs_segment
    # Sender ID: Provider ID (258966)
    sender_id = edi_sender_id
    # Receiver ID: Clearinghouse (ZIRMED)
    receiver_id = edi_receiver_id
    date_str = Date.today.strftime("%Y%m%d")
    time_str = Time.current.strftime("%H%M")
    @group_control_number = generate_group_control_number

    [
      "GS",
      "HC", # Functional Identifier Code (HC=Health Care Claim)
      sender_id, # GS03 - Application Sender Code (Provider: 258966)
      receiver_id, # GS04 - Application Receiver Code (Clearinghouse: ZIRMED)
      date_str, # GS05 - Date
      time_str, # GS06 - Time
      @group_control_number, # GS07 - Group Control Number (must match GE02)
      "X", # GS08 - Responsible Agency Code
      "005010X222A1" # GS09 - Version/Release/Industry Identifier (837P 5010)
    ].join("*")
  end

  def build_st_segment(encounter)
    @st_segment_count += 1
    # ST02 must be zero-padded 4-digit number, and must match SE02 exactly
    st_control_number = @st_segment_count.to_s.rjust(4, "0")
    @st_control_numbers[encounter.id] = st_control_number

    [
      "ST",
      "837", # Transaction Set Identifier
      st_control_number, # Transaction Set Control Number (zero-padded, must match SE02)
      "005010X222A1" # Implementation Reference
    ].join("*")
  end

  def build_bht_segment(encounter)
    date_str = encounter.date_of_service&.strftime("%Y%m%d") || Date.today.strftime("%Y%m%d")
    time_str = Time.current.strftime("%H%M%S")

    [
      "BHT",
      "0019", # Hierarchical Structure Code
      "00", # Transaction Set Purpose Code (00=Original)
      "ENC#{encounter.id}", # Claim or Encounter Identifier
      date_str,
      time_str,
      "CH" # Claim or Encounter Identifier
    ].join("*")
  end

  def build_se_segment(encounter, segment_count)
    # SE02 must exactly match ST02 (the control number we stored)
    st_control_number = @st_control_numbers[encounter.id] || "0001"

    [
      "SE",
      segment_count.to_s, # SE01 = number of segments from ST to SE inclusive
      st_control_number # SE02 = Transaction Set Control Number (must match ST02 exactly)
    ].join("*")
  end

  def build_ge_segment
    # GE01 = number of ST segments (transaction sets) in this functional group
    # GE02 = Group Control Number (must match GS07)
    [
      "GE",
      @st_segment_count.to_s, # GE01 - Number of transaction sets (ST segments)
      @group_control_number.to_s # GE02 - Group Control Number (same as GS07)
    ].join("*")
  end

  def build_iea_segment
    [
      "IEA",
      "1", # Number of Included Functional Groups
      pad(@interchange_control_number, 9) # Interchange Control Number (same as ISA)
    ].join("*")
  end

  # ============================================================
  # 1000A - SUBMITTER (MUST)
  # ============================================================

  def build_submitter_receiver_loops
    segments = []

    # 1000A - Submitter
    # NM109 is required when qualifier 46 is provided
    segments << [
      "NM1",
      "41", # Entity Type Code (41=Submitter)
      "2", # Entity Type Qualifier (2=Non-Person Entity)
      @organization.name,
      "", # Name First
      "", # Name Middle
      "", # Name Prefix
      "", # Name Suffix
      "46", # Identification Code Qualifier (46=Electronic Transmitter Identification Number)
      EDI_SENDER_ID # ETIN (Sender ID: 258966)
    ].join("*")

    # 1000B - Receiver (Waystar)
    # NM109 is required when qualifier 46 is provided
    segments << [
      "NM1",
      "40", # Entity Type Code (40=Receiver)
      "2", # Entity Type Qualifier (2=Non-Person Entity)
      "WAYSTAR",
      "", # Name First
      "", # Name Middle
      "", # Name Prefix
      "", # Name Suffix
      "46", # Identification Code Qualifier
      EDI_RECEIVER_ID # ETIN (Receiver ID: ZIRMED)
    ].join("*")

    segments
  end

  # ============================================================
  # 2000A - BILLING PROVIDER (MUST)
  # ============================================================

  def build_billing_provider_loop(encounter)
    segments = []
    org = encounter.organization
    org_contact = org.organization_contact
    org_identifier = org.organization_identifier

    @hl_counter += 1

    # HL - Hierarchical Level - MUST
    segments << [
      "HL",
      @hl_counter.to_s, # Hierarchical ID Number
      "", # Parent Hierarchical ID Number (empty for root)
      "20", # Hierarchical Level Code (20=Information Source)
      "1" # Hierarchical Child Code (1=Additional Subordinate HL Data)
    ].join("*")

    # NM1 - Billing Provider Name - MUST
    # NPI is mandatory when qualifier XX is used
    billing_npi = org_identifier&.npi
    unless billing_npi.present?
      raise "Billing Provider NPI is required for encounter #{encounter.id}"
    end

    segments << [
      "NM1",
      "85", # Entity Type Code (85=Billing Provider)
      "2", # Entity Type Qualifier (2=Non-Person Entity)
      org.name,
      "", # Name First
      "", # Name Middle
      "", # Name Prefix
      "", # Name Suffix
      "XX", # Identification Code Qualifier (XX=National Provider Identifier)
      billing_npi # NPI (mandatory)
    ].join("*")

    # N3 - Billing Provider Street Address - MUST
    if org_contact&.address_line1.present?
      segments << [
        "N3",
        org_contact.address_line1,
        org_contact.address_line2 || ""
      ].join("*")
    else
      raise "Billing Provider address (N3) is required"
    end

    # N4 - Billing Provider City/State/ZIP - MUST (required if N3 present)
    if org_contact&.city.present?
      segments << [
        "N4",
        org_contact.city,
        org_contact.state || "",
        org_contact.zip || "",
        org_contact.country || ""
      ].join("*")
    else
      raise "Billing Provider city/state/zip (N4) is required"
    end

    # REF - Tax Identification Number - SHOULD (effectively required)
    if org_identifier&.tax_identification_number.present?
      tax_id_type = org_identifier.tax_id_type == "ein" ? "EI" : "SS"
      segments << [
        "REF",
        tax_id_type, # Reference Identification Qualifier
        org_identifier.tax_identification_number
      ].join("*")
    end

    segments
  end

  # ============================================================
  # 2000B - SUBSCRIBER (MUST)
  # ============================================================

  def build_subscriber_loop(encounter)
    segments = []
    patient = encounter.patient
    coverage = encounter.patient_insurance_coverage

    @hl_counter += 1
    parent_hl = @hl_counter - 1

    # HL - Subscriber Hierarchical Level - MUST
    segments << [
      "HL",
      @hl_counter.to_s, # Hierarchical ID Number
      parent_hl.to_s, # Parent Hierarchical ID Number
      "22", # Hierarchical Level Code (22=Subscriber)
      patient_different_from_subscriber?(encounter) ? "0" : "1" # 0=Child, 1=No Children
    ].join("*")

    if coverage.present?
      # SBR - Subscriber Information - MUST
      insurance_type_code = map_insurance_type(coverage.insurance_plan)
      relationship_code = map_relationship_to_subscriber(coverage.relationship_to_subscriber)

      segments << [
        "SBR",
        "P", # Payer Responsibility Sequence Number Code (P=Primary)
        relationship_code, # Individual Relationship Code
        "", # Reference Identification (Group or Policy Number)
        "", # Name
        "", # Insurance Type Code
        "", # Claim Filing Indicator Code
        "", # Non-covered Charges
        "", # Patient Responsibility Amount
        insurance_type_code # Insurance Type Code
      ].join("*")

      # 2010BA - Subscriber Name - MUST
      subscriber_name = coverage.subscriber_name
      name_parts = parse_name(subscriber_name)

      segments << [
        "NM1",
        "IL", # Entity Type Code (IL=Insured or Subscriber)
        "1", # Entity Type Qualifier (1=Person)
        name_parts[:last],
        name_parts[:first],
        name_parts[:middle] || "",
        name_parts[:prefix] || "",
        name_parts[:suffix] || "",
        "MI", # Identification Code Qualifier (MI=Member Identification Number)
        coverage.member_id
      ].join("*")

      # N3 - Subscriber Address - SHOULD
      if coverage.subscriber_address.present?
        addr = coverage.subscriber_address
        if addr["line1"].present?
          segments << [
            "N3",
            addr["line1"] || "",
            addr["line2"] || ""
          ].join("*")

          # N4 - Subscriber City/State/ZIP - MUST if N3 present
          segments << [
            "N4",
            addr["city"] || "",
            addr["state"] || "",
            addr["postal"] || "",
            addr["country"] || ""
          ].join("*")
        end
      end

      # DMG - Subscriber Demographic Information - SHOULD (strongly recommended)
      if patient.dob.present?
        segments << [
          "DMG",
          "D8", # Date Time Period Format Qualifier
          patient.dob.strftime("%Y%m%d"),
          patient.sex_at_birth&.upcase || ""
        ].join("*")
      end

      # REF - Group Number - SHOULD (required if plan has group number)
      if coverage.insurance_plan&.group_number.present?
        segments << [
          "REF",
          "6P", # Reference Identification Qualifier (6P=Group Number)
          coverage.insurance_plan.group_number
        ].join("*")
      end

      # 2010BB - Payer Name Loop - MUST for insurance claims
      if coverage.insurance_plan.present?
        payer_name = coverage.insurance_plan.name || "UNKNOWN PAYER"
        payer_id = coverage.insurance_plan.payer_id || ""

        segments << [
          "NM1",
          "PR", # Entity Type Code (PR=Payer)
          "2", # Entity Type Qualifier (2=Non-Person Entity)
          payer_name,
          "", # Name First
          "", # Name Middle
          "", # Name Prefix
          "", # Name Suffix
          "PI", # Identification Code Qualifier (PI=Payer Identification)
          payer_id # Payer ID (required)
        ].join("*")
      end
    else
      # Self-pay - Subscriber is the patient
      segments << [
        "SBR",
        "S", # Payer Responsibility Sequence Number Code (S=Self-pay)
        "18", # Individual Relationship Code (18=Self)
        "", # Reference Identification
        "", # Name
        "", # Insurance Type Code
        "", # Claim Filing Indicator Code
        "", # Non-covered Charges
        "", # Patient Responsibility Amount
        "" # Insurance Type Code
      ].join("*")

      segments << [
        "NM1",
        "IL",
        "1",
        patient.last_name,
        patient.first_name,
        "", # Middle
        "", # Prefix
        "", # Suffix
        "", # Identification Code Qualifier
        "" # Identification Code
      ].join("*")

      if patient.dob.present?
        segments << [
          "DMG",
          "D8",
          patient.dob.strftime("%Y%m%d"),
          patient.sex_at_birth&.upcase || ""
        ].join("*")
      end
    end

    segments
  end

  # ============================================================
  # 2000C - PATIENT (MUST only when patient ≠ subscriber)
  # ============================================================

  def build_patient_loop(encounter)
    segments = []
    patient = encounter.patient

    return segments unless patient_different_from_subscriber?(encounter)

    @hl_counter += 1
    parent_hl = @hl_counter - 1

    # HL - Patient Hierarchical Level - MUST
    segments << [
      "HL",
      @hl_counter.to_s, # Hierarchical ID Number
      parent_hl.to_s, # Parent Hierarchical ID Number (Subscriber)
      "23", # Hierarchical Level Code (23=Patient)
      "0" # Hierarchical Child Code (0=No Subordinate HL Segment)
    ].join("*")

    # 2010CA - Patient Name - MUST
    segments << [
      "NM1",
      "QC", # Entity Type Code (QC=Patient)
      "1", # Entity Type Qualifier (1=Person)
      patient.last_name,
      patient.first_name,
      "", # Middle
      "", # Prefix
      "", # Suffix
      "", # Identification Code Qualifier
      "" # Identification Code
    ].join("*")

    # N3 - Patient Address - SHOULD
    if patient.address_line_1.present?
      segments << [
        "N3",
        patient.address_line_1,
        patient.address_line_2 || ""
      ].join("*")

      # N4 - Patient City/State/ZIP - MUST if N3 present
      segments << [
        "N4",
        patient.city || "",
        patient.state || "",
        patient.postal || "",
        patient.country || ""
      ].join("*")
    end

    # DMG - Patient Demographic Information - MUST / strongly enforced
    if patient.dob.present?
      segments << [
        "DMG",
        "D8", # Date Time Period Format Qualifier
        patient.dob.strftime("%Y%m%d"),
        patient.sex_at_birth&.upcase || ""
      ].join("*")
    else
      raise "Patient date of birth (DMG) is required"
    end

    segments
  end

  # ============================================================
  # 2300 - CLAIM INFORMATION (MUST)
  # ============================================================

  def build_claim_loop(encounter)
    segments = []
    patient = encounter.patient
    provider = encounter.provider

    @hl_counter += 1
    parent_hl = patient_different_from_subscriber?(encounter) ? @hl_counter - 1 : @hl_counter - 1

    # Calculate total charge from procedure items
    procedure_items = encounter.encounter_procedure_items.includes(:procedure_code)
    total_charge = calculate_total_charge(encounter, procedure_items)
    has_service_lines = procedure_items.any?

    # HL - Claim Hierarchical Level - MUST
    segments << [
      "HL",
      @hl_counter.to_s,
      parent_hl.to_s,
      "23", # Hierarchical Level Code (23=Claim)
      has_service_lines ? "1" : "0" # 1=Additional Subordinate HL Data (has service lines)
    ].join("*")

    # CLM - Claim Information - MUST
    # CLM01 should be patient control number only (no composite)
    patient_account_number = patient.mrn || "PAT#{patient.id}"
    place_of_service = encounter.organization_location&.place_of_service_code || "11"

    segments << [
      "CLM",
      patient_account_number, # CLM01 - Patient Account Number (Box 26) - no composite
      format_currency(total_charge), # CLM02 - Total Claim Charge Amount (Box 28)
      "", # CLM03 - Non-covered Charges
      "", # CLM04 - Patient Responsibility Amount
      place_of_service, # CLM05-1 - Place of Service Code (Box 24B)
      "", # CLM05-2 - Facility Code Qualifier
      "", # CLM05-3 - Facility Code Value
      "Y", # CLM07 - Accept Assignment (Box 27) - MUST, Default = Y
      "", # CLM08 - Benefits Assignment Certification Indicator
      "", # CLM09 - Release of Information Code
      build_related_causes(encounter), # CLM11 - Related Causes Information (Box 10)
      "", # CLM12 - Special Program Indicator
      "", # CLM13 - Level of Service Code
      "", # CLM14 - Provider Agreement Code
      "", # CLM15 - Claim Status Code
      "", # CLM16 - Claim Submission Reason Code
      "", # CLM17 - Delay Reason Code
      "" # CLM18 - Claim Note
    ].join("*")

    # DTP - Claim-level dates - SHOULD
    if encounter.date_of_service.present?
      segments << [
        "DTP",
        "431", # Date Time Qualifier (431=Onset of Current Symptoms or Illness)
        "D8", # Date Time Period Format Qualifier
        encounter.date_of_service.strftime("%Y%m%d")
      ].join("*")
    end

    # HI - Health Care Diagnosis Code - MUST (≥1, allow up to 12)
    diagnosis_codes = encounter.diagnosis_codes.limit(12).to_a
    if diagnosis_codes.empty?
      raise "At least one diagnosis code (HI) is required"
    end

    hi_codes = diagnosis_codes.map.with_index do |dx, idx|
      qualifier = idx == 0 ? "BK" : "BF" # BK=Principal Diagnosis, BF=Diagnosis
      "#{qualifier}:#{dx.code}"
    end.join("^")

    segments << [
      "HI",
      hi_codes
    ].join("*")

    # DTP - Accident Date - MUST if accident indicated
    if encounter_has_accident?(encounter)
      # Accident date field doesn't exist in schema yet, use date of service
      accident_date = encounter.date_of_service
      if accident_date.present?
        segments << [
          "DTP",
          "439", # Date Time Qualifier (439=Accident Date)
          "D8",
          accident_date.strftime("%Y%m%d")
        ].join("*")
      end
    end

    # REF - Prior Authorization - SHOULD (Box 23)
    # Check if prior authorization is stored in metadata or notes
    prior_auth = extract_prior_authorization(encounter)
    if prior_auth.present?
      segments << [
        "REF",
        "G1", # Reference Identification Qualifier (G1=Prior Authorization Number)
        prior_auth
      ].join("*")
    end

    # 2310A - Referring Provider (Box 17) - OPTIONAL
    # Referring provider field doesn't exist in schema yet
    # Skip for now - can be added later if needed
    referring_provider_id = nil # encounter.referring_provider_id
    if referring_provider_id.present?
      referring_provider = Provider.find_by(id: referring_provider_id)
      if referring_provider
        segments << [
          "NM1",
          "DN", # Entity Type Code (DN=Referring Provider)
          "1", # Entity Type Qualifier (1=Person)
          referring_provider.last_name || "",
          referring_provider.first_name || "",
          "", # Middle
          "", # Prefix
          "", # Suffix
          "XX", # Identification Code Qualifier (XX=National Provider Identifier)
          referring_provider.npi || ""
        ].join("*")
      end
    end

    # 2310B - Rendering Provider (Box 24J) - MUST
    if provider.present?
      segments << [
        "NM1",
        "82", # Entity Type Code (82=Rendering Provider)
        "1", # Entity Type Qualifier (1=Person)
        provider.last_name || "",
        provider.first_name || "",
        "", # Middle
        "", # Prefix
        "", # Suffix
        "XX", # Identification Code Qualifier (XX=National Provider Identifier)
        provider.npi || ""
      ].join("*")
    else
      raise "Rendering Provider (NM1) is required"
    end

    # REF - Rendering Provider Secondary Identification - OPTIONAL
    if provider&.license_number.present?
      segments << [
        "REF",
        "0B", # Reference Identification Qualifier (0B=State License Number)
        provider.license_number
      ].join("*")
    end

    # 2310C - Service Facility Location (Box 32) - SHOULD
    service_location = encounter.organization_location

    if service_location.present? && service_location.address_line_1.present?
      # Service location different from billing address
      segments << [
        "NM1",
        "77", # Entity Type Code (77=Service Location)
        "2", # Entity Type Qualifier (2=Non-Person Entity)
        service_location.name || encounter.organization.name,
        "", # Name First
        "", # Name Middle
        "", # Name Prefix
        "", # Name Suffix
        "XX", # Identification Code Qualifier
        service_location.billing_npi || organization_identifier&.npi || ""
      ].join("*")

      segments << [
        "N3",
        service_location.address_line_1,
        service_location.address_line_2 || ""
      ].join("*")

      segments << [
        "N4",
        service_location.city || "",
        service_location.state || "",
        service_location.postal_code || "",
        service_location.country || ""
      ].join("*")
    end

    segments
  end

  # ============================================================
  # 2400 - SERVICE LINES (MUST)
  # ============================================================

  def build_service_line_loops(encounter)
    segments = []
    procedure_items = encounter.encounter_procedure_items.includes(:procedure_code).to_a

    procedure_items.each_with_index do |item, index|
      line_number = index + 1
      procedure_code = item.procedure_code

      # Get pricing from fee schedule
      pricing_result = FeeSchedulePricingService.resolve_pricing(
        encounter.organization_id,
        encounter.provider_id,
        procedure_code.id
      )

      # Calculate units and amount
      unit_price = pricing_result[:success] ? pricing_result[:pricing][:unit_price].to_f : 0.0
      pricing_rule = pricing_result[:success] ? pricing_result[:pricing][:pricing_rule] : "flat"
      units = 1 # Default to 1 unit, can be enhanced based on duration if needed
      amount_billed = if pricing_rule == "flat"
        unit_price
      else
        unit_price * units
      end

      # LX - Service Line Number - MUST
      segments << [
        "LX",
        line_number.to_s
      ].join("*")

      # SV1 - Professional Service - MUST
      line_charge = format_currency(amount_billed)

      # Build diagnosis pointers (first 4 diagnosis codes)
      diagnosis_codes = encounter.diagnosis_codes.limit(4).pluck(:id)
      dx_pointers = diagnosis_codes.map.with_index { |_, idx| idx + 1 }
      dx_pointer_str = dx_pointers.map { |p| p.to_s }.join("^")

      # SV1 format: SV1*HC:CODE*AMOUNT*UN*UNITS***DX_POINTERS
      # Get the actual procedure code string, not the object
      procedure_code_str = procedure_code.code

      segments << [
        "SV1",
        "HC:#{procedure_code_str}", # SV101 - Product/Service ID (HC:CODE format)
        line_charge, # SV102 - Line Item Charge Amount
        "UN", # SV103 - Unit or Basis for Measurement Code (UN=Unit)
        units.to_s, # SV104 - Service Unit Count
        "", # Unit Rate
        "", # Unit for Measurement Code
        dx_pointer_str, # Composite Diagnosis Code Pointer
        "", # Monetary Amount
        "", # Yes/No Condition or Response Code
        "", # Multiple Procedure Code Indicator
        "" # Yes/No Condition or Response Code
      ].join("*")

      # DTP - Service Line Date of Service (Box 24A) - MUST
      service_date = encounter.date_of_service
      if service_date.present?
        segments << [
          "DTP",
          "472", # Date Time Qualifier (472=Service)
          "D8", # Date Time Period Format Qualifier
          service_date.strftime("%Y%m%d")
        ].join("*")
      else
        raise "Service line date of service (DTP) is required"
      end

      # LINCTP - Line Item Control (Drug/Compound Information) - CONDITIONAL
      # Required for J-codes (drug supply), forbidden for administration CPTs
      if requires_linctp?(procedure_code.code)
        segments << build_linctp_segment(item, procedure_code.code, units)
      elsif is_administration_cpt?(procedure_code)
        # Explicitly do NOT add LINCTP for administration CPTs
        # This is handled by the conditional check above
      end

      # 2420A - Rendering Provider (Line Level) - OPTIONAL (only if rendering varies by line)
      # Not implemented - using claim-level rendering provider
    end

    segments
  end

  # ============================================================
  # DRUG ADMINISTRATION LOGIC
  # ============================================================

  # Administration CPT codes that require drug supply lines
  ADMINISTRATION_CPTS = %w[96360 96361 96365 96366 96367].freeze

  # Drug supply HCPCS codes that require LINCTP
  DRUG_SUPPLY_CODES_REQUIRING_LINCTP = %w[J0655 J3301].freeze

  def is_administration_cpt?(procedure_code)
    ADMINISTRATION_CPTS.include?(procedure_code)
  end

  def is_drug_supply_code?(procedure_code)
    procedure_code.to_s.match?(/\AJ/i) # Starts with J (drug supply pattern)
  end

  def requires_linctp?(procedure_code)
    # Rule: If service line code matches drug supply pattern (starts with J), require LINCTP
    # Rule: If service line is administration CPT, forbid LINCTP
    return false if is_administration_cpt?(procedure_code)
    return true if is_drug_supply_code?(procedure_code)
    return true if DRUG_SUPPLY_CODES_REQUIRING_LINCTP.include?(procedure_code)
    false
  end

  def build_linctp_segment(procedure_item, procedure_code, units)
    # LINCTP - Line Item Control (Drug/Compound Information)
    # Format: LINCTP*[Compound Code]*[Compound Description]*[Quantity]*[Unit of Measure]*

    # For J-codes, provide drug information
    drug_info = get_drug_information(procedure_code)

    [
      "LINCTP",
      procedure_code, # Compound Code (HCPCS code)
      drug_info[:description] || "", # Compound Description
      units.to_s, # Quantity
      "", # Unit of Measure (if applicable)
      "", # Additional fields as needed
      "" # Additional fields
    ].join("*")
  end

  def calculate_total_charge(encounter, procedure_items)
    total = 0.0

    procedure_items.each do |item|
      procedure_code = item.procedure_code
      next unless procedure_code.present?

      # Get pricing from fee schedule
      pricing_result = FeeSchedulePricingService.resolve_pricing(
        encounter.organization_id,
        encounter.provider_id,
        procedure_code.id
      )

      # Calculate amount
      unit_price = pricing_result[:success] ? pricing_result[:pricing][:unit_price].to_f : 0.0
      pricing_rule = pricing_result[:success] ? pricing_result[:pricing][:pricing_rule] : "flat"
      units = 1 # Default to 1 unit

      amount = if pricing_rule == "flat"
        unit_price
      else
        unit_price * units
      end

      total += amount
    end

    total
  end

  def get_drug_information(procedure_code)
    # Map known drug codes to descriptions
    drug_map = {
      "J0655" => "Bupivacaine",
      "J3301" => "Triamcinolone Acetonide"
    }

    {
      description: drug_map[procedure_code] || ""
    }
  end

  # ============================================================
  # VALIDATION
  # ============================================================

  def validate_encounters
    errors = []

    @encounters.each do |encounter|
      # Must have patient
      unless encounter.patient.present?
        errors << "Encounter #{encounter.id}: Patient is required"
      end

      # Must have rendering provider
      unless encounter.provider.present?
        errors << "Encounter #{encounter.id}: Rendering Provider is required"
      end

      # Must have at least one diagnosis code
      if encounter.diagnosis_codes.empty?
        errors << "Encounter #{encounter.id}: At least one diagnosis code (HI) is required"
      end

      # Must have at least one procedure code
      procedure_items = encounter.encounter_procedure_items.includes(:procedure_code)
      if procedure_items.empty?
        errors << "Encounter #{encounter.id}: At least one procedure code is required"
        next
      end

      # Validate procedure items
      procedure_items.each_with_index do |item, idx|
        unless item.procedure_code.present?
          errors << "Encounter #{encounter.id}, Line #{idx + 1}: Procedure code is required"
        end

        procedure_code = item.procedure_code&.code
        next unless procedure_code.present?

        # Drug administration validation
        if is_administration_cpt?(procedure_code)
          # Rule: If administration CPT present, expect at least one drug supply line
          has_drug_supply = procedure_items.any? do |other_item|
            other_code = other_item.procedure_code&.code
            other_code.present? && is_drug_supply_code?(other_code) && other_item.id != item.id
          end

          unless has_drug_supply
            errors << "Encounter #{encounter.id}, Line #{idx + 1}: Administration CPT #{procedure_code} requires at least one drug supply line (J-code)"
          end
        end

        # Rule: J-codes require LINCTP (enforced in build_linctp_segment)
        if is_drug_supply_code?(procedure_code) && !requires_linctp?(procedure_code)
          errors << "Encounter #{encounter.id}, Line #{idx + 1}: Drug supply code #{procedure_code} requires LINCTP segment"
        end

        # Rule: Administration CPTs must NOT have LINCTP (enforced in build_linctp_segment)
        if is_administration_cpt?(procedure_code) && requires_linctp?(procedure_code)
          errors << "Encounter #{encounter.id}, Line #{idx + 1}: Administration CPT #{procedure_code} must NOT have LINCTP segment"
        end
      end

      # Accident validation
      if encounter_has_accident?(encounter)
        # Accident date field doesn't exist in schema, use date_of_service
        unless encounter.date_of_service.present?
          errors << "Encounter #{encounter.id}: Date of service is required when accident is indicated"
        end
      end

      # Billing provider validation
      org_contact = encounter.organization.organization_contact
      unless org_contact&.address_line1.present?
        errors << "Encounter #{encounter.id}: Billing Provider address (N3) is required"
      end

      unless org_contact&.city.present?
        errors << "Encounter #{encounter.id}: Billing Provider city/state/zip (N4) is required"
      end
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # ============================================================
  # HELPER METHODS
  # ============================================================

  def patient_different_from_subscriber?(encounter)
    coverage = encounter.patient_insurance_coverage
    return false unless coverage.present?

    # Patient is different from subscriber if relationship is not "self"
    coverage.relationship_to_subscriber != "self"
  end

  def encounter_has_accident?(encounter)
    # Check if encounter has accident-related information
    # Accident fields don't exist in the schema yet
    # For now, check if there's a note indicating accident
    encounter.notes&.downcase&.include?("accident") rescue false
  end

  def build_related_causes(encounter)
    return "" unless encounter_has_accident?(encounter)

    # AA = Auto Accident, EM = Employment, OA = Other Accident
    # Accident type and state fields don't exist in schema yet
    # Default to Other Accident
    "OA"
  end

  def map_insurance_type(insurance_plan)
    return "" unless insurance_plan.present?

    # Map insurance plan type to code
    # Common codes: CI=Commercial Insurance, HM=HMO, etc.
    insurance_plan.plan_type || "CI" rescue "CI"
  end

  def map_relationship_to_subscriber(relationship)
    case relationship.to_s
    when "self" then "18"
    when "spouse" then "01"
    when "child" then "19"
    when "other" then "G8"
    else "18"
    end
  end

  def organization_identifier
    @organization_identifier ||= @organization.organization_identifier
  end

  def pad(str, length)
    str.to_s.ljust(length, " ")[0...length]
  end

  def format_currency(amount)
    return "" if amount.nil?
    sprintf("%.2f", amount.to_f)
  end

  def parse_name(full_name)
    parts = full_name.to_s.strip.split(/\s+/)
    {
      first: parts[0] || "",
      middle: (parts.length > 2 ? parts[1..-2].join(" ") : ""),
      last: parts[-1] || "",
      prefix: "",
      suffix: ""
    }
  end

  def generate_filename
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    org_id = @organization.id
    "837P_#{org_id}_#{timestamp}.edi"
  end

  # EDI Configuration Methods

  def edi_sender_id
    # Get from Rails credentials, fallback to constant
    # Sender ID: 258966 (Provider ID)
    Rails.application.credentials.dig(:waystar, :edi_sender_id) || EDI_SENDER_ID
  end

  def edi_receiver_id
    # Get from Rails credentials, fallback to constant
    # Receiver ID: ZIRMED (Clearinghouse)
    Rails.application.credentials.dig(:waystar, :edi_receiver_id) || EDI_RECEIVER_ID
  end

  def generate_interchange_control_number
    # Generate unique interchange control number
    # Format: 9 digits, incrementing
    # In production, this should be stored and incremented per organization
    timestamp = Time.current.to_i
    (timestamp % 999999999).to_s.rjust(9, "0")
  end

  def generate_group_control_number
    # Generate unique group control number
    # Format: numeric, incrementing
    # In production, this should be stored and incremented per organization
    timestamp = Time.current.to_i
    (timestamp % 999999).to_s
  end

  def extract_prior_authorization(encounter)
    # Prior authorization number is not a direct field on encounters
    # Check if it's stored in metadata or notes
    # For now, return nil (optional field)
    # TODO: Add prior_authorization_number field to encounters table if needed
    nil
  end
end
