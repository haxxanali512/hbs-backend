class ProcedureCodeValidationService
  class << self
    # Validates if a procedure code can be used for a specific specialty
    def validate_specialty_usage(procedure_code, specialty)
      return { valid: true } if procedure_code.specialties.include?(specialty)

      {
        valid: false,
        error: "SPEC_CPT_NOT_ALLOWED - Procedure not permitted under this specialty"
      }
    end

    # Validates if a procedure code has required fee schedule rates
    def validate_fee_schedule_rate(procedure_code, organization_id, provider_id = nil)
      result = FeeSchedulePricingService.resolve_pricing(organization_id, provider_id, procedure_code.id)

      if result[:success]
        { valid: true }
      else
        {
          valid: false,
          error: "FEE_SCHEDULE_RATE_REQUIRED - Rate must be defined by Client_Admin for this procedure"
        }
      end
    end

    # Validates if a procedure code can be used (not retired)
    def validate_code_status(procedure_code)
      if procedure_code.retired?
        {
          valid: false,
          error: "PROC_CODE_RETIRED - This code is retired and cannot be used on new encounters/claims"
        }
      else
        { valid: true }
      end
    end

    # Validates if a procedure code is unique within its type
    def validate_code_uniqueness(procedure_code)
      existing = ProcedureCode.kept.where(code: procedure_code.code, code_type: procedure_code.code_type)
      existing = existing.where.not(id: procedure_code.id) if procedure_code.persisted?

      if existing.exists?
        {
          valid: false,
          error: "PROC_CODE_DUPLICATE - Code must be unique within code type"
        }
      else
        { valid: true }
      end
    end

    # Comprehensive validation for procedure code usage
    def validate_usage(procedure_code, organization_id, specialty_id = nil, provider_id = nil)
      validations = [
        validate_code_status(procedure_code),
        validate_code_uniqueness(procedure_code)
      ]

      if specialty_id.present?
        specialty = Specialty.find(specialty_id)
        validations << validate_specialty_usage(procedure_code, specialty)
      end

      validations << validate_fee_schedule_rate(procedure_code, organization_id, provider_id)

      # Return first validation error found
      failed_validation = validations.find { |v| !v[:valid] }
      failed_validation || { valid: true }
    end

    # Validates plan rule compliance (placeholder for future implementation)
    def validate_plan_rules(procedure_code, plan_id = nil)
      # This would integrate with plan-specific rules
      # For now, always return valid
      { valid: true }
    end
  end
end
