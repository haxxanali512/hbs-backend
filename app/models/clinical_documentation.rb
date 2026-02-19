class ClinicalDocumentation < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    image/gif
    image/webp
  ].freeze

  ALLOWED_EXTENSIONS = %w[pdf jpg jpeg png gif webp].freeze

  belongs_to :encounter
  belongs_to :organization
  belongs_to :patient
  belongs_to :author_provider, class_name: "Provider"
  belongs_to :signed_by_provider, class_name: "Provider", optional: true
  belongs_to :cosigner_provider, class_name: "Provider", optional: true

  has_one_attached :file

  enum :document_type, {
    clinical_note: 0,
    file_upload: 1
  }, prefix: true

  enum :status, {
    draft: 0,
    signed: 1
  }, prefix: true

  before_validation :set_content_json_default
  before_validation :set_document_type_for_file_upload, on: :create
  before_validation :copy_associations_from_encounter, if: -> { encounter.present? && (new_record? || encounter_id_changed?) }

  validates :document_type, presence: true
  # validates :content_json, presence: true
  validate :file_content_type_allowed
  validate :file_size_within_limit
  validate :file_upload_requires_file, if: :document_type_file_upload?

  scope :with_file, -> { joins(:file_attachment) }

  def file_name
    file.filename.to_s if file.attached?
  end

  private

  def set_content_json_default
    self.content_json = {} if content_json.blank?
  end

  def set_document_type_for_file_upload
    return unless document_type.blank? && file.attached?

    self.document_type = :file_upload
  end

  def copy_associations_from_encounter
    return unless encounter.present?

    self.organization_id = encounter.organization_id
    self.patient_id = encounter.patient_id
    self.author_provider_id = encounter.provider_id if author_provider_id.blank?
  end

  def file_content_type_allowed
    return unless file.attached?

    unless file.content_type.in?(ALLOWED_CONTENT_TYPES)
      errors.add(:file, "must be PDF or image (JPEG, PNG, GIF, WebP)")
    end
  end

  def file_size_within_limit
    return unless file.attached?

    if file.blob.byte_size > 25.megabytes
      errors.add(:file, "must be 25MB or less")
    end
  end

  def file_upload_requires_file
    return unless document_type == "file_upload"

    unless file.attached?
      errors.add(:file, "must be attached for file upload documentation")
    end
  end
end
