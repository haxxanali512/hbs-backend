class Prescription < ApplicationRecord
  include Discard::Model

  audited

  belongs_to :patient
  # Documents now use Active Storage
  has_many_attached :documents

  validates :expires_on, presence: true
  validates :title, presence: true

  scope :active, -> { kept.where(expired: false) }
  scope :expired, -> { kept.where(expired: true) }
end
