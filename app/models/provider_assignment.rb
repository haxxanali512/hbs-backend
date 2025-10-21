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

  private

  def set_default_role
    self.role ||= "primary"
  end

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def can_be_activated?
    !active?
  end

  def can_be_deactivated?
    active?
  end
end
