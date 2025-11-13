class ProviderNote < ApplicationRecord
  audited

  # Associations
  belongs_to :encounter
  belongs_to :provider

  # Validations
  validates :encounter_id, presence: true
  validates :provider_id, presence: true
  validates :note_text, presence: true

  # Business Rules
  validate :encounter_not_finalized_on_edit, on: :update
  validate :provider_can_edit_own_notes, on: :update

  # Scopes
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def can_be_edited?
    !encounter.cascaded?
  end

  def finalized?
    encounter.cascaded?
  end

  private

  def encounter_not_finalized_on_edit
    if encounter.cascaded? && note_text_changed?
      errors.add(:base, "NOTE_EDIT_LOCKED - Cannot edit notes after encounter finalization.")
    end
  end

  def provider_can_edit_own_notes
    # This will be enforced at the controller/policy level
    # But we can add a validation if needed
  end
end
