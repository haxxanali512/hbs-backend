class User < ApplicationRecord
  audited
  include Discard::Model
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :invitable, :lockable

  # Associations
  belongs_to :role, optional: true
  has_many :organizations, foreign_key: "owner_id", dependent: :destroy
  has_many :organization_memberships, dependent: :destroy
  has_many :member_organizations, through: :organization_memberships, source: :organization, dependent: :destroy
  has_many :encounter_comments, foreign_key: "author_user_id", dependent: :destroy
  has_many :encounter_comment_seens, dependent: :destroy

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
    role.scope == "global" ? "hbs_dashboard" : "tenant_dashboard"
  end

  def display_name
    full_name.presence || username || email
  end

  def permissions_for(type, controller, action)
    role.access.dig(type, controller, action)
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
    return false unless role&.access
    permissions_for("admin", "encounters", "show") || permissions_for("admin", "encounter_comments", "create")
  end

  def has_tenant_access?
    return false unless role&.access
    permissions_for("tenant", "encounters", "show") || permissions_for("tenant", "encounter_comments", "create")
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
end
