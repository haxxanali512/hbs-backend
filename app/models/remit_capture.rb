class RemitCapture < ApplicationRecord
  audited

  belongs_to :capturable, polymorphic: true

  enum :capture_type, {
    attachment: 0,
    export_job: 1
  }

  # Validations
  validates :capturable_type, :capturable_id, presence: true
  validates :capture_type, presence: true
  validates :label, presence: true
  validates :service_period_start, :service_period_end, presence: true
  validate :service_period_end_after_start

  # Instance methods
  def file_url
    # Placeholder for future Active Storage or S3 integration
    file_path
  end

  private

  def service_period_end_after_start
    return if service_period_start.blank? || service_period_end.blank?
    errors.add(:service_period_end, "must be after service period start") if service_period_end < service_period_start
  end
end
