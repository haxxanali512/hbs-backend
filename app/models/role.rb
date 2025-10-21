class Role < ApplicationRecord
  audited
  include Discard::Model

  has_many :users
  has_many :organization_memberships, foreign_key: "organization_role_id"

  enum :scope, { global: 0, tenant: 1 }

  validates :role_name, presence: true
  validates :scope, presence: true

  # Ensure access is always a Hash
  before_validation :ensure_access_hash

  scope :global_roles, -> { where(scope: :global) }
  scope :tenant_roles, -> { where(scope: :tenant) }

  private

  def ensure_access_hash
    self.access ||= {}
  end
end
