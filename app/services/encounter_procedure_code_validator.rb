# Service to validate encounter procedure codes against business rules
class EncounterProcedureCodeValidator
  attr_reader :encounter, :errors

  def initialize(encounter)
    @encounter = encounter
    @errors = []
  end

  def validate
    @errors = []
    procedure_codes = get_procedure_codes

    return { valid: true } if procedure_codes.empty?

    procedure_codes.each do |proc_code|
      rule = ProcedureCodeRule.find_by(procedure_code: proc_code)
      next unless rule

      validate_unit_limits(proc_code, rule)
      validate_cannot_be_billed_with(proc_code, rule, procedure_codes)
      validate_requires_codes(proc_code, rule, procedure_codes)
      validate_clinical_documentation(proc_code, rule)
      validate_frequency_limits(proc_code, rule)
      validate_new_patient_restrictions(proc_code, rule)
      validate_one_per_diagnosis(proc_code, rule)
    end

    if @errors.any?
      { valid: false, errors: @errors }
    else
      { valid: true }
    end
  end

  private

  def get_procedure_codes
    # Get procedure codes from virtual attribute or association
    if @encounter.procedure_code_ids.present?
      ProcedureCode.where(id: Array(@encounter.procedure_code_ids).reject(&:blank?))
    elsif @encounter.encounter_procedure_items.any?
      @encounter.procedure_codes
    else
      []
    end
  end

  def get_procedure_code_units(proc_code)
    # Get units for a specific procedure code from claim lines or encounter_procedure_items
    if @encounter.claim.present?
      claim_line = @encounter.claim.claim_lines.find_by(procedure_code: proc_code)
      claim_line&.units || 1
    elsif @encounter.encounter_procedure_items.any?
      item = @encounter.encounter_procedure_items.find_by(procedure_code: proc_code)
      item&.units || 1
    else
      # Default to 1 unit if not specified
      1
    end
  end

  def get_procedure_code_codes(procedure_codes)
    procedure_codes.map(&:code)
  end

  def validate_unit_limits(proc_code, rule)
    limit = rule.unit_limit
    return unless limit

    units = get_procedure_code_units(proc_code)
    if units > limit
      @errors << "PROC_UNIT_LIMIT_EXCEEDED - #{proc_code.code} (#{rule.procedure_code.description}) exceeds unit limit of #{limit}. Current units: #{units}"
    elsif units < 1
      @errors << "PROC_UNIT_MINIMUM - #{proc_code.code} (#{rule.procedure_code.description}) requires at least 1 unit"
    end
  end

  def validate_cannot_be_billed_with(proc_code, rule, all_procedure_codes)
    forbidden_codes = rule.cannot_be_billed_with
    return if forbidden_codes.empty?

    all_codes = get_procedure_code_codes(all_procedure_codes)
    # Remove current code from comparison to avoid false positives
    all_codes = all_codes - [ proc_code.code ]
    conflicting_codes = forbidden_codes & all_codes

    if conflicting_codes.any?
      @errors << "PROC_CONFLICT - #{proc_code.code} (#{rule.procedure_code.description}) cannot be billed with: #{conflicting_codes.join(', ')}"
    end
  end

  def validate_requires_codes(proc_code, rule, all_procedure_codes)
    required_codes = rule.requires_codes
    return if required_codes.empty?

    all_codes = get_procedure_code_codes(all_procedure_codes)
    missing_codes = required_codes - all_codes

    if missing_codes.any?
      @errors << "PROC_REQUIRES - #{proc_code.code} (#{rule.procedure_code.description}) requires: #{missing_codes.join(' or ')}"
    end
  end

  def validate_clinical_documentation(proc_code, rule)
    return unless rule.requires_clinical_documentation?

    has_documentation = @encounter.documents.any? ||
                       @encounter.primary_clinical_documentation.present? ||
                       (@encounter.respond_to?(:clinical_documentations) && @encounter.clinical_documentations.any?)

    unless has_documentation
      @errors << "PROC_REQUIRES_DOCUMENTATION - #{proc_code.code} (#{rule.procedure_code.description}) requires clinical documentation"
    end
  end

  def validate_frequency_limits(proc_code, rule)
    frequency = rule.frequency_limit
    return unless frequency

    # Check if patient has had this procedure code in the last X months
    months_ago = frequency[:months].months.ago
    count_limit = frequency[:count]

    recent_encounters = @encounter.organization.encounters
                                  .where(patient_id: @encounter.patient_id)
                                  .where.not(id: @encounter.id)
                                  .where("date_of_service >= ?", months_ago)
                                  .joins(:procedure_codes)
                                  .where(procedure_codes: { code: proc_code.code })
                                  .count

    if recent_encounters >= count_limit
      @errors << "PROC_FREQUENCY_LIMIT - #{proc_code.code} (#{rule.procedure_code.description}) is limited to #{count_limit} per #{frequency[:months]} months. Patient has already had #{recent_encounters} in the last #{frequency[:months]} months."
    end
  end

  def validate_new_patient_restrictions(proc_code, rule)
    return unless rule.new_patient_only?

    years_ago = rule.new_patient_years.years.ago
    has_previous_encounters = @encounter.organization.encounters
                                        .where(patient_id: @encounter.patient_id)
                                        .where.not(id: @encounter.id)
                                        .where("date_of_service >= ?", years_ago)
                                        .exists?

    if has_previous_encounters
      @errors << "PROC_NEW_PATIENT_ONLY - #{proc_code.code} (#{rule.procedure_code.description}) is only allowed for new patients (no encounters with this organization in the previous #{rule.new_patient_years} years)"
    end
  end

  def validate_one_per_diagnosis(proc_code, rule)
    return unless rule.one_per_diagnosis?

    # Check if this procedure code is already used with the same diagnosis codes
    diagnosis_code_ids = @encounter.diagnosis_codes.pluck(:id)
    return if diagnosis_code_ids.empty?

    existing_encounters = @encounter.organization.encounters
                                   .where(patient_id: @encounter.patient_id)
                                   .where.not(id: @encounter.id)
                                   .joins(:diagnosis_codes)
                                   .where(diagnosis_codes: { id: diagnosis_code_ids })
                                   .joins(:procedure_codes)
                                   .where(procedure_codes: { code: proc_code.code })
                                   .exists?

    if existing_encounters
      @errors << "PROC_ONE_PER_DIAGNOSIS - #{proc_code.code} (#{rule.procedure_code.description}) can only be used once per diagnosis code combination"
    end
  end
end
