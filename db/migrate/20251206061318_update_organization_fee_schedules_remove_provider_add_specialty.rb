class UpdateOrganizationFeeSchedulesRemoveProviderAddSpecialty < ActiveRecord::Migration[7.2]
  def change
    # Remove provider_id column and its index
    remove_index :organization_fee_schedules, :provider_id, if_exists: true
    remove_reference :organization_fee_schedules, :provider, foreign_key: true, null: false
    
    # Add specialty_id column (optional, nullable)
    add_reference :organization_fee_schedules, :specialty, foreign_key: true, null: true
    
    # Remove the composite index on organization_id and provider_id if it exists
    remove_index :organization_fee_schedules, 
                 name: 'index_org_fee_schedules_on_org_and_provider', 
                 if_exists: true
  end
end
