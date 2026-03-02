# Stores file attachments on encounter comments (conversational thread artifacts).
# Distinct from Clinical Documentation, which is the formal doc repository for the encounter.
class EncounterCommentAttachment < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    image/gif
    image/webp
  ].freeze

  ALLOWED_EXTENSIONS = %w[pdf jpg jpeg png gif webp].freeze

  belongs_to :encounter_comment
  has_one_attached :file

  validate :file_content_type_allowed
  validate :file_size_within_limit
  validate :file_required

  def file_name
    file.filename.to_s if file.attached?
  end

  private

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

  def file_required
    return if file.attached?

    errors.add(:file, "must be present")
  end
end
