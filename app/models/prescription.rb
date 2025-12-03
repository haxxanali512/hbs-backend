class Prescription < ApplicationRecord
  include Discard::Model

  audited

  belongs_to :patient
  has_many :documents, as: :documentable, dependent: :destroy

  validates :expires_on, presence: true
  validates :title, presence: true

  scope :active, -> { kept.where(expired: false) }
  scope :expired, -> { kept.where(expired: true) }
end
