class FeeScheduleUnlockService
  # Unlock procedure codes for an organization when a specialty is added
  # (triggered when a provider with a specialty is assigned to an organization)
  def self.unlock_procedure_codes_for_organization(organization, specialty)
    return unless organization.present? && specialty.present?
    return unless specialty.active?

    # Get or create the organization's fee schedule
    fee_schedule = organization.get_or_create_fee_schedule(specialty)

    # Get all active procedure codes from the specialty
    procedure_codes = specialty.procedure_codes.active

    unlocked_count = 0
    procedure_codes.each do |procedure_code|
      # Check if item already exists (dedupe handled by unique constraint)
      existing_item = fee_schedule.organization_fee_schedule_items
        .find_by(procedure_code_id: procedure_code.id)

      if existing_item.nil?
        # Create new item with null unit_price (rate will be entered later by Client_Admin)
        fee_schedule.organization_fee_schedule_items.create!(
          procedure_code_id: procedure_code.id,
          unit_price: nil, # Will be filled by Client_Admin
          pricing_rule: :price_per_unit, # Default, can be changed later
          active: true
        )
        unlocked_count += 1
      end
      # If exists, do nothing (dedupe handled automatically by unique constraint)
    end

    {
      success: true,
      unlocked_count: unlocked_count,
      total_codes: procedure_codes.count
    }
  rescue => e
    Rails.logger.error "Error unlocking procedure codes: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      error: e.message
    }
  end

  # Check and deactivate fee schedule items when specialty/provider is removed
  # (called when provider assignment is removed or specialty is removed)
  def self.check_and_deactivate_unlocked_codes(organization)
    return unless organization.present?

    deactivated_count = 0
    organization.organization_fee_schedule_items.active.each do |item|
      unless organization.procedure_code_unlocked?(item.procedure_code_id)
        item.update(active: false)
        deactivated_count += 1
      end
    end

    {
      success: true,
      deactivated_count: deactivated_count
    }
  rescue => e
    Rails.logger.error "Error checking unlocked codes: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    {
      success: false,
      error: e.message
    }
  end
end
