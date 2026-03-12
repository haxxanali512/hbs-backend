class Appointment < ApplicationRecord
  audited
  include Discard::Model

  # Associations
  belongs_to :organization
  belongs_to :organization_location
  belongs_to :provider
  belongs_to :patient
  belongs_to :specialty
  has_many :encounters, dependent: :restrict_with_error

  # Enums
  enum appointment_type: {
    consultation: 0,
    follow_up: 1,
    initial_evaluation: 2,
    treatment: 3,
    procedure: 4,
    other: 5
  }

  enum status: {
    scheduled: 0,
    confirmed: 1,
    in_progress: 2,
    completed: 3,
    cancelled: 4,
    no_show: 5
  }

  # Callbacks
  before_save :calculate_duration

  # Validations
  validates :appointment_type, presence: true
  validates :status, presence: true
  validates :scheduled_start_at, presence: true
  validates :scheduled_end_at, presence: true
  validates :provider_id, presence: true
  validates :patient_id, presence: true
  validates :specialty_id, presence: true
  validates :organization_location_id, presence: true
  validate :end_after_start
  validate :scheduled_start_in_future_or_allow_past
  validate :provider_belongs_to_organization
  validate :patient_belongs_to_organization
  validate :location_belongs_to_organization
  validate :specialty_belongs_to_organization

  # Scopes
  scope :upcoming, -> { where("scheduled_start_at > ?", Time.current).order(scheduled_start_at: :asc) }
  scope :past, -> { where("scheduled_start_at < ?", Time.current).order(scheduled_start_at: :desc) }
  scope :today, -> { where("DATE(scheduled_start_at) = ?", Date.current) }
  scope :this_week, -> { where("scheduled_start_at >= ? AND scheduled_start_at <= ?", Date.current.beginning_of_week, Date.current.end_of_week) }
  scope :this_month, -> { where("scheduled_start_at >= ? AND scheduled_start_at <= ?", Date.current.beginning_of_month, Date.current.end_of_month) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_provider, ->(provider_id) { where(provider_id: provider_id) }
  scope :by_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :by_specialty, ->(specialty_id) { where(specialty_id: specialty_id) }
  scope :by_location, ->(location_id) { where(organization_location_id: location_id) }
  scope :search, ->(term) {
    joins(:patient, :provider)
      .where(
        "patients.first_name ILIKE ? OR patients.last_name ILIKE ? OR providers.first_name ILIKE ? OR providers.last_name ILIKE ?",
        "%#{term}%", "%#{term}%", "%#{term}%", "%#{term}%"
      )
  }
  scope :with_reason, -> { where.not(reason_for_visit: [ nil, "" ]) }

  # Instance Methods
  def display_name
    "#{patient.full_name} - #{provider.full_name} - #{scheduled_start_at.strftime('%m/%d/%Y %I:%M %p')}"
  end

  def patient_name
    "#{patient.first_name} #{patient.last_name}"
  end

  def provider_name
    provider.full_name
  end

  def formatted_scheduled_time
    scheduled_start_at.strftime("%m/%d/%Y at %I:%M %p")
  end

  def duration_in_minutes
    duration_minutes || ((scheduled_end_at - scheduled_start_at) / 60) if scheduled_end_at && scheduled_start_at
  end

  def is_upcoming?
    scheduled_start_at > Time.current
  end

  def is_past?
    scheduled_start_at < Time.current
  end

  def is_today?
    scheduled_start_at.to_date == Date.current
  end

  def can_be_cancelled?
    scheduled? || confirmed?
  end

  def can_be_rescheduled?
    scheduled? || confirmed?
  end

  def can_be_completed?
    status != "completed" && status != "cancelled"
  end

  def status_badge_color
    case status
    when "scheduled" then "bg-blue-100 text-blue-800"
    when "confirmed" then "bg-green-100 text-green-800"
    when "in_progress" then "bg-yellow-100 text-yellow-800"
    when "completed" then "bg-gray-100 text-gray-800"
    when "cancelled" then "bg-red-100 text-red-800"
    when "no_show" then "bg-orange-100 text-orange-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  def type_badge_color
    case appointment_type
    when "consultation" then "bg-purple-100 text-purple-800"
    when "follow_up" then "bg-blue-100 text-blue-800"
    when "initial_evaluation" then "bg-indigo-100 text-indigo-800"
    when "treatment" then "bg-green-100 text-green-800"
    when "procedure" then "bg-orange-100 text-orange-800"
    when "other" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  private

  def calculate_duration
    if scheduled_start_at.present? && scheduled_end_at.present?
      self.duration_minutes = ((scheduled_end_at - scheduled_start_at) / 60).round
    end
  end

  def end_after_start
    if scheduled_start_at.present? && scheduled_end_at.present?
      if scheduled_end_at <= scheduled_start_at
        errors.add(:scheduled_end_at, "must be after scheduled start time")
      end
    end
  end

  def scheduled_start_in_future_or_allow_past
    # Allow past appointments for historical data import
    return if persisted? || scheduled_start_at.blank?

    # Only warn if scheduling in the past (more than 1 hour ago)
    if scheduled_start_at < 1.hour.ago && !persisted?
      errors.add(:scheduled_start_at, "cannot be more than 1 hour in the past")
    end
  end

  def provider_belongs_to_organization
    return unless provider.present? && organization.present?

    unless provider.organizations.include?(organization)
      errors.add(:provider_id, "does not belong to this organization")
    end
  end

  def patient_belongs_to_organization
    return unless patient.present? && organization.present?

    unless patient.organization_id == organization.id
      errors.add(:patient_id, "does not belong to this organization")
    end
  end

  def location_belongs_to_organization
    return unless organization_location.present? && organization.present?

    unless organization_location.organization_id == organization.id
      errors.add(:organization_location_id, "does not belong to this organization")
    end
  end

  def specialty_belongs_to_organization
    return unless specialty.present?

    # Verify specialty is active
    unless specialty.active?
      errors.add(:specialty_id, "must be an active specialty")
    end
  end
end
