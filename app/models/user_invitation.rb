class UserInvitation < ApplicationRecord
  # Associations
  belongs_to :invited_by, class_name: "User"
  belongs_to :role
  has_one :user, dependent: :nullify

  # Validations
  validates :invited_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :email_not_already_registered
  validate :expires_at_in_future

  # Callbacks
  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  # Scopes
  scope :pending, -> { where(accepted_at: nil) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired, -> { where("expires_at < ?", Time.now) }
  scope :valid, -> { pending.where("expires_at > ?", Time.now) }

  # Class methods
  def self.create_invitation!(invited_by:, invited_email:, role:, expires_in: 7.days)
    create!(
      invited_by: invited_by,
      invited_email: invited_email,
      role: role,
      expires_at: expires_in.from_now
    )
  end

  def self.find_valid_invitation(token)
    valid.find_by(token: token)
  end

  # Instance methods
  def accepted?
    accepted_at.present?
  end

  def expired?
    expires_at < Time.now
  end

  def valid?
    !accepted? && !expired?
  end

  def accept!(user)
    return false unless valid?

    update!(accepted_at: Time.now)
    user.update!(user_invitation: self) if user.persisted?
    true
  end

  def resend!(expires_in: 7.days)
    return false if accepted?

    update!(
      token: generate_unique_token,
      expires_at: expires_in.from_now
    )
    true
  end

  def expire!
    update!(expires_at: Time.now)
  end

  def invitation_url
    Rails.application.routes.url_helpers.accept_user_invitation_url(
      invitation_token: token,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end

  private

  def generate_token
    self.token = generate_unique_token
  end

  def generate_unique_token
    loop do
      token = SecureRandom.uuid
      break token unless UserInvitation.exists?(token: token)
    end
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end

  def email_not_already_registered
    return unless invited_email.present?

    if User.exists?(email: invited_email)
      errors.add(:invited_email, "is already registered")
    end
  end

  def expires_at_in_future
    return unless expires_at.present?

    if expires_at <= Time.now
      errors.add(:expires_at, "must be in the future")
    end
  end
end
