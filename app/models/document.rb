class Document < ApplicationRecord
  audited
  belongs_to :documentable, polymorphic: true
  belongs_to :created_by, class_name: "User"
  belongs_to :organization
  has_many :document_attachments, dependent: :destroy

  validates :title, presence: true
  validates :status, inclusion: { in: %w[draft pending approved rejected archived] }
  validates :document_type, presence: true

  enum :status, {
    draft: "draft",
    pending: "pending",
    approved: "approved",
    rejected: "rejected",
    archived: "archived"
  }

  scope :by_type, ->(type) { where(document_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  def primary_attachment
    document_attachments.find_by(is_primary: true) || document_attachments.first
  end

  def file_count
    document_attachments.count
  end

  def total_file_size
    document_attachments.sum(:file_size)
  end

  def can_be_edited?
    draft? || pending?
  end

  def can_be_approved?
    pending?
  end

  def can_be_rejected?
    pending?
  end

  def can_be_archived?
    approved? || rejected?
  end

  # Linked resource helper for support tickets (Agreement)
  def self.patient_agreements(organization, patient_id = nil)
    return none unless organization

    scope = where(organization_id: organization.id)
    if patient_id.present?
      scope = scope.where(documentable_type: "Patient", documentable_id: patient_id)
    end

    scope.order(created_at: :desc)
  end
end
