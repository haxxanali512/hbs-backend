class User < ApplicationRecord
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

  def display_name
    full_name.presence || username || email
  end

  def permissions_for(action, main_module, sub_module)
    return nil unless role&.respond_to?(:access)

    role.access.dig(main_module, sub_module, action)
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
end
