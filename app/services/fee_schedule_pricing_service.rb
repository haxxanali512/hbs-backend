class FeeSchedulePricingService
  class << self
    # Resolves pricing for a given encounter/claim_line
    # Enforces: One active item per (organization_id, procedure_code_id)
    # Provider_id parameter kept for future flexibility but not used in lookup
    def resolve_pricing(organization_id, provider_id, procedure_code_id)
      # Find any active item for this organization and procedure code
      # Only one active item should exist per org per procedure code
      item = OrganizationFeeScheduleItem
                                       .joins(:organization_fee_schedule)
                                       .where(organization_fee_schedules: {
                                         organization_id: organization_id
                                       })
                                       .where(procedure_code_id: procedure_code_id)
                                       .where(active: true)
                                       .first

      if item
        schedule = item.organization_fee_schedule

        return {
          success: true,
          pricing: item.pricing_snapshot,
          source: "org_wide",
          schedule_id: schedule.id,
          item_id: item.id
        }
      end

      # No applicable schedule found
      {
        success: false,
        error: "FEE_SCHEDULE_NOT_FOUND - No applicable fee schedule for this organization.",
        organization_id: organization_id,
        provider_id: provider_id,
        procedure_code_id: procedure_code_id
      }
    end

    # Get all available pricing for an organization
    # Note: All fee schedules are now org-wide (no provider-specific)
    def get_provider_pricing(organization_id, provider_id = nil)
      # Get all org-wide pricing items
      org_items = OrganizationFeeScheduleItem
                                            .joins(:organization_fee_schedule)
                                            .where(organization_fee_schedules: {
                                              organization_id: organization_id,
                                              locked: false
                                            })
                                            .where(active: true)
                                            .includes(:procedure_code, :organization_fee_schedule)

      {
        org_wide: org_items.map(&:pricing_snapshot),
        total_items: org_items.count
      }
    end

    # Get pricing summary for an organization
    def get_organization_pricing_summary(organization_id)
      schedules = OrganizationFeeSchedule.kept
                                        .where(organization_id: organization_id)
                                        .includes(:organization_fee_schedule_items)

      {
        total_schedules: schedules.count,
        locked_schedules: schedules.locked.count,
        total_items: schedules.joins(:organization_fee_schedule_items).count,
        active_items: schedules.joins(:organization_fee_schedule_items)
                              .where(organization_fee_schedule_items: { active: true })
                              .count
      }
    end

    # Validate pricing rule compatibility
    def validate_pricing_rule(procedure_code_id, pricing_rule)
      # For now, support only the two main rules used in the UI
      valid_rules = %w[price_per_unit flat]

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
      items = OrganizationFeeScheduleItem
                                        .joins(:organization_fee_schedule)
                                        .where(organization_fee_schedules: { organization_id: organization_id })
                                        .includes(:procedure_code, :organization_fee_schedule)

      items = items.where(procedure_code_id: procedure_code_id) if procedure_code_id.present?

      items.order(created_at: :desc)
    end
  end
end
