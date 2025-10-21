class DocumentAttachment < ApplicationRecord
  belongs_to :document
  belongs_to :uploaded_by, class_name: "User"

  validates :file_name, presence: true
  validates :file_path, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :file_hash, presence: true, uniqueness: { scope: :document_id }

  scope :primary, -> { where(is_primary: true) }
  scope :by_type, ->(type) { where(file_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  def file_extension
    File.extname(file_name).downcase
  end

  def file_size_mb
    (file_size / 1024.0 / 1024.0).round(2)
  end

  def file_size_kb
    (file_size / 1024.0).round(2)
  end

  def image?
    %w[.jpg .jpeg .png .gif .bmp .webp].include?(file_extension)
  end

  def pdf?
    file_extension == ".pdf"
  end

  def document?
    %w[.pdf .doc .docx .txt .rtf].include?(file_extension)
  end

  def spreadsheet?
    %w[.xls .xlsx .csv].include?(file_extension)
  end

  def presentation?
    %w[.ppt .pptx].include?(file_extension)
  end

  def archive?
    %w[.zip .rar .7z .tar .gz].include?(file_extension)
  end

  def formatted_file_size
    if file_size_mb >= 1
      "#{file_size_mb} MB"
    else
      "#{file_size_kb} KB"
    end
  end

  def display_name
    file_name.length > 50 ? "#{file_name[0..47]}..." : file_name
  end

  def set_as_primary!
    transaction do
      document.document_attachments.update_all(is_primary: false)
      update!(is_primary: true)
    end
  end
end
