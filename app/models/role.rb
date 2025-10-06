class Role < ApplicationRecord
  has_many :users

  validates :role_name, presence: true, uniqueness: true

  # Ensure access is always a Hash
  before_validation :ensure_access_hash

  private

  def ensure_access_hash
    self.access ||= {}
  end
end
