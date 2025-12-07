class User < ApplicationRecord
  audited
  include Discard::Model
  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable, :trackable and :omniauthable
  devise :two_factor_authenticatable,
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

  # ===========================================
  # Two-Factor Authentication (MFA) Methods
  # ===========================================

  # Check if MFA is enabled for this user
  def mfa_enabled?
    otp_required_for_login? && otp_secret.present?
  end

  # Enable MFA - generate and save OTP secret
  def enable_mfa!
    self.otp_secret = User.generate_otp_secret
    self.otp_required_for_login = true
    save!
  end

  # Disable MFA
  def disable_mfa!
    self.otp_secret = nil
    self.otp_required_for_login = false
    self.consumed_timestep = nil
    save!
  end

  # Generate provisioning URI for authenticator apps
  def mfa_provisioning_uri
    otp_provisioning_uri(email, issuer: "HBS Healthcare")
  end

  # Generate QR code as SVG for the provisioning URI
  def mfa_qr_code_svg
    return nil unless otp_secret.present?

    qrcode = RQRCode::QRCode.new(mfa_provisioning_uri)
    qrcode.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )
  end
end
