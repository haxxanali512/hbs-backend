class Organization < ApplicationRecord
  audited
  include Discard::Model

  include AASM

  enum :activation_status, {
    pending: 0,
    compliance_setup: 1,
    billing_setup: 2,
    document_signing: 3,
    activated: 4
  }

  aasm column: "activation_status", enum: true do
    state :pending, initial: true
    state :compliance_setup
    state :billing_setup
    state :document_signing
    state :activated

    event :compliance_setup_complete! do
      transitions from: :pending, to: :compliance_setup
    end

    event :billing_setup_complete! do
      transitions from: :compliance_setup, to: :billing_setup
    end

    event :document_signing_complete! do
      transitions from: :billing_setup, to: :document_signing
    end

    event :activate do
      transitions from: :document_signing, to: :activated
    end
  end

  belongs_to :owner, class_name: "User", foreign_key: "owner_id"
  has_many :organization_memberships, dependent: :destroy
  has_many :members, through: :organization_memberships, source: :user
  has_one :organization_billing, dependent: :destroy
  has_one :organization_compliance, dependent: :destroy
  has_one :organization_contact, dependent: :destroy
  has_one :organization_identifier, dependent: :destroy
  has_one :organization_setting, dependent: :destroy
  has_many :invoices, dependent: :restrict_with_error
  has_many :payments, dependent: :restrict_with_error
  has_many :provider_assignments, dependent: :destroy
  has_many :providers, through: :provider_assignments
  has_many :documents, as: :documentable, dependent: :destroy
  has_many :organization_fee_schedules, dependent: :destroy
  after_create :invite_owner

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true
  validates :owner, presence: true

  def activation_progress_percentage
    case activation_status
    when "pending" then 0
    when "compliance_setup" then 25
    when "billing_setup" then 50
    when "document_signing" then 75
    when "activated" then 100
    else 0
    end
  end

  def next_activation_step
    case activation_status
    when "pending" then "billing_setup"
    when "compliance_setup" then "billing_setup"
    when "billing_setup" then "document_signing"
    when "document_signing" then "activated"
    else nil
    end
  end

  def can_proceed_to_step?(step)
    case step
    when "billing_setup" then pending?
    when "compliance_setup" then compliance_setup?
    when "document_signing" then billing_setup?
    when "activated" then document_signing?
    else false
    end
  end

  def activated?
    activation_status == "activated"
  end

  def active_members
    members.where(organization_memberships: { active: true })
  end

  def add_member(user, role = nil)
    organization_memberships.create!(user: user, organization_role: role, active: true)
  end

  def invite_owner
    owner.invite!
  end

  def remove_member(user)
    membership = organization_memberships.find_by(user: user)
    membership&.deactivate!
  end
end
