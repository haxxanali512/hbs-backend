class ReferralPartner < ApplicationRecord
  COMMISSION_PERCENT = BigDecimal("12.0")
  PARTNER_TYPES = %i[existing_client provider consultant agency wellness_business employee_contractor other].freeze

  audited

  belongs_to :user, optional: true
  belongs_to :linked_client_organization, class_name: "Organization", optional: true

  has_many :referral_relationships, dependent: :destroy
  has_many :referral_commissions, through: :referral_relationships

  enum :partner_type, PARTNER_TYPES.index_with.with_index { |_key, index| index }
  enum :status, { pending: 0, approved: 1, denied: 2, suspended: 3 }

  validates :first_name, :last_name, :email, :partner_type, :status, presence: true
  validates :email, uniqueness: { case_sensitive: false }
  validates :referral_code, uniqueness: true, allow_blank: true

  scope :active_for_referrals, -> { approved.where.not(referral_code: [ nil, "" ]) }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def active_for_referrals?
    approved? && referral_code.present?
  end
end
