class User < ApplicationRecord
  audited
  include Discard::Model
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :invitable, :lockable, :masqueradable

  # Associations
  belongs_to :role, optional: true
  has_many :organizations, foreign_key: "owner_id", dependent: :destroy
  has_many :organization_memberships, dependent: :destroy
  has_many :member_organizations, through: :organization_memberships, source: :organization, dependent: :destroy
  has_many :encounter_comments, foreign_key: "author_user_id", dependent: :destroy
  has_many :encounter_comment_seens, dependent: :destroy
  has_many :created_support_tickets,
           class_name: "SupportTicket",
           foreign_key: "created_by_user_id",
           dependent: :nullify
  has_many :assigned_support_tickets,
           class_name: "SupportTicket",
           foreign_key: "assigned_to_user_id",
           dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_one :referral_partner, dependent: :nullify

  # after_create :send_invitation


  # Validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :first_name, presence: true
  validates :last_name, presence: true

  enum :status, {
    pending: 0,
    active: 1,
    inactive: 2
  }

  accepts_nested_attributes_for :organizations


  # Instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def dashboard_type
    case default_portal_context
    when :admin
      "hbs_dashboard"
    when :referral_partner
      "referral_partner_dashboard"
    else
      "tenant_dashboard"
    end
  end

  def display_name
    full_name.presence || username || email
  end

  def permissions_for(type, controller, action)
    normalized_access.dig(type.to_s, controller.to_s, action.to_s)
  end

  def super_admin?
    role&.role_name == "Super Admin"
  end

  def admin?
    super_admin? || role&.role_name&.include?("Admin")
  end

  def organization_admin?(organization)
    return true if super_admin?
    return false unless organization

    membership = organization_memberships.active.find_by(organization: organization)
    membership&.organization_role&.role_name&.include?("Admin")
  end

  def member_of?(organization)
    return true if super_admin?
    organization_memberships.active.exists?(organization: organization)
  end

  def active_organizations
    member_organizations.where(organization_memberships: { active: true })
  end

  def has_admin_access?
    return true if super_admin?
    namespace_access_enabled?("admin")
  end

  def has_tenant_access?
    namespace_access_enabled?("tenant")
  end

  def has_referral_partner_access?
    namespace_access_enabled?("referral_partner")
  end

  def hbs_user?
    super_admin? || role&.global?
  end

  def client_user?
    !hbs_user?
  end

  def can_create_shared_comment?
    has_admin_access? || has_tenant_access?
  end

  def can_create_internal_comment?
    has_admin_access?
  end

  def can_redact_comment?
    return true if super_admin?
    return false unless role&.access
    permissions_for("admin", "encounter_comments", "redact")
  end

  def can_view_internal_comments?
    has_admin_access?
  end

  def organization_id
    # Return the first active organization's ID for tenant users
    active_organizations.first&.id
  end

  def available_portal_contexts
    contexts = []
    contexts << :admin if has_admin_access?
    contexts << :tenant if has_tenant_access? && active_organizations.exists?
    contexts << :referral_partner if has_referral_partner_access? && referral_partner.present?
    contexts
  end

  def default_portal_context
    available_portal_contexts.first
  end

  def multiple_portal_contexts?
    available_portal_contexts.many?
  end

  private

  def normalized_access
    @normalized_access ||= role&.access.is_a?(Hash) ? role.access.deep_stringify_keys : {}
  end

  def namespace_access_enabled?(namespace)
    namespace_access = normalized_access[namespace.to_s]
    return false unless namespace_access.is_a?(Hash)

    namespace_access.values.any? do |controller_permissions|
      next false unless controller_permissions.is_a?(Hash)

      controller_permissions.values.any?(true)
    end
  end
end
