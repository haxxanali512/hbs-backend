class OrganizationMembership < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :organization_role, class_name: "Role", optional: true

  validates :user_id, uniqueness: { scope: :organization_id }
  validates :active, inclusion: { in: [ true, false ] }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def deactivate!
    update!(active: false)
  end

  def activate!
    update!(active: true)
  end
end
