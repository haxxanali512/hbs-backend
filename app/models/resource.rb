class Resource < ApplicationRecord
  audited

  RESOURCE_TYPES = %w[article blog video pdf link other].freeze

  has_one_attached :file

  enum :status, {
    draft: 0,
    published: 1
  }

  validates :title, presence: true
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }, allow_blank: true

  scope :published, -> { where(status: :published) }
  scope :featured_first, -> { order(featured: :desc, created_at: :desc) }

  scope :by_type, ->(type) {
    type.present? ? where(resource_type: type) : all
  }

  scope :search, ->(term) {
    return all if term.blank?

    like = "%#{term.strip}%"
    where("title ILIKE ? OR description ILIKE ? OR tags ILIKE ?", like, like, like)
  }

  def tag_list
    (tags || "").split(",").map(&:strip).reject(&:blank?)
  end

  def tag_list=(array_or_string)
    list = Array(array_or_string).join(",") if array_or_string.is_a?(Array)
    self.tags = (list || array_or_string.to_s).split(",").map(&:strip).reject(&:blank?).join(", ")
  end
end

