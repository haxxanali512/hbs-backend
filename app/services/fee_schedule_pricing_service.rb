class FeeSchedulePricingService
  class << self
    # Resolves pricing for a given encounter/claim_line
    # Priority: provider_specific -> org_wide -> error
    def resolve_pricing(organization_id, provider_id, procedure_code_id)
      # First try provider-specific schedule
      provider_schedule = OrganizationFeeSchedule.kept
                                                 .where(organization_id: organization_id, provider_id: provider_id)
                                                 .joins(:organization_fee_schedule_items)
                                                 .where(organization_fee_schedule_items: {
                                                   procedure_code_id: procedure_code_id,
                                                   active: true
                                                 })
                                                 .first

      if provider_schedule
        item = provider_schedule.organization_fee_schedule_items
                               .where(procedure_code_id: procedure_code_id, active: true)
                               .first

        return {
          success: true,
          pricing: item.pricing_snapshot,
          source: "provider_specific",
          schedule_id: provider_schedule.id,
          item_id: item.id
        }
      end

      # Fallback to org-wide schedule
      org_schedule = OrganizationFeeSchedule.kept
                                           .where(organization_id: organization_id, provider_id: nil)
                                           .joins(:organization_fee_schedule_items)
                                           .where(organization_fee_schedule_items: {
                                             procedure_code_id: procedure_code_id,
                                             active: true
                                           })
                                           .first

      if org_schedule
        item = org_schedule.organization_fee_schedule_items
                          .where(procedure_code_id: procedure_code_id, active: true)
                          .first

        return {
          success: true,
          pricing: item.pricing_snapshot,
          source: "org_wide",
          schedule_id: org_schedule.id,
          item_id: item.id
        }
      end

      # No applicable schedule found
      {
        success: false,
        error: "FEE_SCHEDULE_NOT_FOUND - No applicable fee schedule for this provider/organization.",
        organization_id: organization_id,
        provider_id: provider_id,
        procedure_code_id: procedure_code_id
      }
    end

    # Get all available pricing for a provider
    def get_provider_pricing(organization_id, provider_id)
      # Get provider-specific pricing
      provider_items = OrganizationFeeScheduleItem.kept
                                                  .joins(:organization_fee_schedule)
                                                  .where(organization_fee_schedules: {
                                                    organization_id: organization_id,
                                                    provider_id: provider_id,
                                                    locked: false
                                                  })
                                                  .where(active: true)
                                                  .includes(:procedure_code, :organization_fee_schedule)

      # Get org-wide pricing for codes not covered by provider-specific
      provider_codes = provider_items.pluck(:procedure_code_id)

      org_items = OrganizationFeeScheduleItem.kept
                                            .joins(:organization_fee_schedule)
                                            .where(organization_fee_schedules: {
                                              organization_id: organization_id,
                                              provider_id: nil,
                                              locked: false
                                            })
                                            .where(active: true)
                                            .where.not(procedure_code_id: provider_codes)
                                            .includes(:procedure_code, :organization_fee_schedule)

      {
        provider_specific: provider_items.map(&:pricing_snapshot),
        org_wide: org_items.map(&:pricing_snapshot),
        total_items: provider_items.count + org_items.count
      }
    end

    # Get pricing summary for an organization
    def get_organization_pricing_summary(organization_id)
      schedules = OrganizationFeeSchedule.kept
                                        .where(organization_id: organization_id)
                                        .includes(:provider, :organization_fee_schedule_items)

      {
        total_schedules: schedules.count,
        org_wide_schedules: schedules.org_wide.count,
        provider_schedules: schedules.provider_specific.count,
        locked_schedules: schedules.locked.count,
        total_items: schedules.joins(:organization_fee_schedule_items).count,
        active_items: schedules.joins(:organization_fee_schedule_items)
                              .where(organization_fee_schedule_items: { active: true })
                              .count
      }
    end

    # Validate pricing rule compatibility
    def validate_pricing_rule(procedure_code_id, pricing_rule)
      # This would check against CPT Rule matrix
      # For now, we'll use a simple validation
      valid_rules = %w[per_unit per_minute per_hour per_visit per_procedure]

      if valid_rules.include?(pricing_rule)
        { valid: true }
      else
        {
          valid: false,
          error: "FEE_RULE_INVALID - Pricing rule not allowed for this CPT."
        }
      end
    end

    # Check if item can be safely deactivated
    def can_deactivate_item?(item_id)
      item = OrganizationFeeScheduleItem.find(item_id)
      !item.referenced_by_claims?
    end

    # Get pricing history for audit
    def get_pricing_history(organization_id, procedure_code_id = nil)
      items = OrganizationFeeScheduleItem.kept
                                        .joins(:organization_fee_schedule)
                                        .where(organization_fee_schedules: { organization_id: organization_id })
                                        .includes(:procedure_code, :organization_fee_schedule)

      items = items.where(procedure_code_id: procedure_code_id) if procedure_code_id.present?

      items.order(created_at: :desc)
    end
  end
end
