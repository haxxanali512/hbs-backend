class Role < ApplicationRecord
  has_many :users
  has_many :organization_memberships, foreign_key: "organization_role_id"
  belongs_to :organization, optional: true

  enum :scope, { global: 0, tenant: 1 }

  validates :role_name, presence: true, uniqueness: { scope: [ :scope, :organization_id ] }
  validates :scope, presence: true

  # Ensure access is always a Hash
  before_validation :ensure_access_hash

  scope :global_roles, -> { where(scope: :global) }
  scope :tenant_roles, -> { where(scope: :tenant) }
  scope :for_organization, ->(org) { where(organization: org) }

  private

  def ensure_access_hash
    self.access ||= {}
  end
end
