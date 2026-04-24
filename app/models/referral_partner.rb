class ReferralPartner < ApplicationRecord
  PARTNER_TYPES = {
    existing_client: 0,
    provider: 1,
    consultant: 2,
    agency: 3,
    wellness_business: 4,
    employee_contractor: 5,
    other: 6
  }.freeze

  belongs_to :user, optional: true
  belongs_to :linked_client, class_name: "Organization", optional: true

  has_many :referral_relationships, dependent: :destroy
  has_many :referral_commissions, through: :referral_relationships

  enum :partner_type, PARTNER_TYPES
  enum :status, {
    pending: 0,
    approved: 1,
    denied: 2,
    suspended: 3
  }

  validates :first_name, :last_name, :email, presence: true
  validates :email, uniqueness: { case_sensitive: false }
  validates :referral_code, uniqueness: true, allow_blank: true

  scope :active_for_attribution, -> { approved.where.not(referral_code: [ nil, "" ]) }

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
