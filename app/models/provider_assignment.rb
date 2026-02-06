class ProviderAssignment < ApplicationRecord
  audited
  include Discard::Model

  belongs_to :provider
  belongs_to :organization

  enum :role, {
    primary: 0,
    secondary: 1,
    consultant: 2
  }

  validates :role, presence: true
  validates :active, inclusion: { in: [ true, false ] }
  validates :provider_id, uniqueness: { scope: :organization_id, message: "Provider is already assigned to this organization" }

  before_validation :set_default_role
  after_create :unlock_procedure_codes_for_specialty
  after_update :handle_active_status_change
  after_discard :check_and_deactivate_codes

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def can_be_activated?
    !active?
  end

  def can_be_deactivated?
    active?
  end

  private

  def set_default_role
    self.role ||= "primary"
  end

  # Unlock procedure codes when provider is assigned to organization
  def unlock_procedure_codes_for_specialty
    return unless active?
    return unless provider.present?

    # Providers can have many specialties; pick a sensible one to unlock codes for.
    primary_specialty =
      if provider.respond_to?(:specialties)
        provider.specialties.active.first || provider.specialties.first
      elsif provider.respond_to?(:specialty)
        provider.specialty
      end

    return unless primary_specialty.present?

    FeeScheduleUnlockService.unlock_procedure_codes_for_organization(
      organization,
      primary_specialty
    )
  end

  # Handle when active status changes
  def handle_active_status_change
    if saved_change_to_active?
      if active?
        # Provider assignment activated - unlock codes
        unlock_procedure_codes_for_specialty
      else
        # Provider assignment deactivated - check if codes should be deactivated
        FeeScheduleUnlockService.check_and_deactivate_unlocked_codes(organization)
      end
    end
  end

  # Check and deactivate codes when provider assignment is removed
  def check_and_deactivate_codes
    FeeScheduleUnlockService.check_and_deactivate_unlocked_codes(organization)
  end
end
