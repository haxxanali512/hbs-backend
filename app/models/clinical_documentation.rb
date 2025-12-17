class ClinicalDocumentation < ApplicationRecord
  include AASM

  audited

  # Relationships
  belongs_to :organization
  belongs_to :encounter
  belongs_to :patient
  belongs_to :author_provider, class_name: "Provider"
  belongs_to :signed_by_provider, class_name: "Provider", optional: true
  belongs_to :cosigner_provider, class_name: "Provider", optional: true
  # belongs_to :template, class_name: "NoteTemplate", optional: true, foreign_key: "template_id" # TODO: Add template_id column in migration

  # Polymorphic document relationship for PDF attachments
  has_one :document, as: :documentable, dependent: :destroy

  # Enums
  enum document_type: {
    soap_note: 0,
    progress_note: 1,
    initial_eval: 2,
    treatment_plan: 3,
    discharge_summary: 4,
    other: 5
  }

  enum status: {
    draft: 0,
    signed: 1,
    amended: 2,
    voided_readonly: 3
  }

  # Validations
  validates :organization_id, presence: true
  validates :encounter_id, presence: true
  validates :patient_id, presence: true
  validates :author_provider_id, presence: true
  validates :document_type, presence: true
  validates :content_json, presence: true
  validates :version_seq, presence: true, numericality: { greater_than: 0 }
  validate :content_json_structure
  validate :content_json_size_limit
  validate :org_encounter_patient_match
  validate :author_provider_in_org
  validate :signed_at_required_when_signed
  validate :signed_by_required_when_signed
  validate :cosigned_at_required_when_cosigned
  validate :immutable_after_signed, on: :update
  validate :attestation_required_if_policy

  # Scopes
  scope :for_encounter, ->(encounter_id) { where(encounter_id: encounter_id) }
  scope :signed, -> { where(status: :signed) }
  scope :draft, -> { where(status: :draft) }
  scope :latest_version, -> { order(version_seq: :desc) }
  scope :by_document_type, ->(type) { where(document_type: type) }

  # State machine
  aasm column: :status, enum: true do
    state :draft, initial: true
    state :signed
    state :amended
    state :voided_readonly

    event :sign do
      transitions from: :draft, to: :signed, guard: :can_sign?
      after do
        self.signed_at = Time.current
        self.signed_by_provider_id ||= author_provider_id
        render_pdf_and_save
      end
    end

    event :amend do
      transitions from: [ :signed, :amended ], to: :amended, guard: :can_amend?
      after do
        create_amended_version
      end
    end

    event :void_readonly do
      transitions from: [ :signed, :amended ], to: :voided_readonly, guard: :can_void?
    end
  end

  # Class methods
  def self.content_schema
    # Basic JSON schema validation - can be extended per document_type
    {
      "type" => "object",
      "properties" => {
        "sections" => {
          "type" => "array",
          "items" => {
            "type" => "object",
            "properties" => {
              "name" => { "type" => "string" },
              "content" => { "type" => "string" }
            },
            "required" => [ "name", "content" ]
          }
        }
      },
      "required" => [ "sections" ]
    }
  end

  # Instance methods
  def can_sign?
    draft? && content_json.present? && author_provider.present?
  end

  def can_amend?
    (signed? || amended?) && !voided_readonly?
  end

  def can_void?
    (signed? || amended?) && !voided_readonly?
  end

  def signed?
    status == "signed" && signed_at.present?
  end

  def cosigned?
    cosigner_provider_id.present? && cosigned_at.present?
  end

  def requires_cosign?
    # Check organization/payer policy
    organization.requires_cosign_for_document_type?(document_type)
  end

  def can_be_edited?
    draft? && !voided_readonly?
  end

  def rendered_pdf_document
    return nil unless document
    # First try to find PDF attachment
    pdf_attachment = document.document_attachments.find_by(file_type: "application/pdf")
    # If no PDF found, return primary attachment (for attached documents)
    pdf_attachment || document.primary_attachment
  end

  def latest_version_for_encounter
    self.class.where(encounter_id: encounter_id)
              .order(version_seq: :desc)
              .first
  end

  def previous_version
    return nil if version_seq <= 1
    self.class.where(encounter_id: encounter_id, version_seq: version_seq - 1).first
  end

  def next_version
    self.class.where(encounter_id: encounter_id, version_seq: version_seq + 1).first
  end

  def content_hash
    Digest::SHA256.hexdigest(content_json.to_json)
  end

  def generate_signature_hash
    self.signature_hash = Digest::SHA256.hexdigest(
      "#{id}-#{content_hash}-#{signed_at}-#{signed_by_provider_id}"
    )
  end

  private

  def content_json_structure
    return unless content_json.present?

    unless content_json.is_a?(Hash)
      errors.add(:content_json, "must be a JSON object")
      return
    end

    unless content_json.key?("sections") && content_json["sections"].is_a?(Array)
      errors.add(:content_json, "must contain a 'sections' array")
      return
    end

    content_json["sections"].each_with_index do |section, index|
      unless section.is_a?(Hash)
        errors.add(:content_json, "section #{index} must be an object")
        next
      end

      unless section.key?("name") && section.key?("content")
        errors.add(:content_json, "section #{index} must have 'name' and 'content' keys")
      end
    end
  rescue JSON::ParserError => e
    errors.add(:content_json, "DOC_SCHEMA_INVALID - Invalid JSON: #{e.message}")
  end

  def content_json_size_limit
    return unless content_json.present?

    size_kb = content_json.to_json.bytesize / 1024.0
    if size_kb > 200
      errors.add(:content_json, "exceeds 200KB limit (#{size_kb.round(2)}KB)")
    end
  end

  def org_encounter_patient_match
    return unless encounter.present? && patient.present?

    if encounter.organization_id != organization_id
      errors.add(:organization_id, "must match encounter's organization")
    end

    if encounter.patient_id != patient_id
      errors.add(:patient_id, "must match encounter's patient")
    end
  end

  def author_provider_in_org
    return unless author_provider.present? && organization.present?

    unless author_provider.organizations.include?(organization)
      errors.add(:author_provider_id, "must belong to the organization")
    end
  end

  def signed_at_required_when_signed
    if signed? && signed_at.blank?
      errors.add(:signed_at, "is required when document is signed")
    end
  end

  def signed_by_required_when_signed
    if signed? && signed_by_provider_id.blank?
      errors.add(:signed_by_provider_id, "is required when document is signed")
    end
  end

  def cosigned_at_required_when_cosigned
    if cosigner_provider_id.present? && cosigned_at.blank?
      errors.add(:cosigned_at, "is required when cosigner is present")
    end
  end

  def immutable_after_signed
    return unless persisted? && (signed? || amended? || voided_readonly?)

    changed_fields = changed - [ "updated_at" ]
    if changed_fields.any?
      errors.add(:base, "DOC_SIGN_IMMUTABLE_FIELDS_CHANGED - Cannot edit signed document. Create an amendment instead.")
    end
  end

  def attestation_required_if_policy
    if requires_cosign? && signed? && attestation_text.blank?
      # Only require if organization policy demands it
      if organization.requires_attestation_for_document_type?(document_type)
        errors.add(:attestation_text, "is required by organization policy")
      end
    end
  end

  def render_pdf_and_save
    # Render PDF and save as document attachment
    ClinicalDocumentationRenderService.new(self).render_and_save
  rescue => e
    Rails.logger.error "Failed to render PDF: #{e.message}"
    errors.add(:base, "DOC_RENDER_FAILED - PDF rendering failed: #{e.message}")
    false
  end

  def create_amended_version
    # Create a new version with incremented version_seq
    new_version = self.class.create!(
      organization_id: organization_id,
      encounter_id: encounter_id,
      patient_id: patient_id,
      author_provider_id: author_provider_id,
      document_type: document_type,
      content_json: content_json,
      version_seq: version_seq + 1,
      # template_id: template_id, # TODO: Add when template_id column is added
      status: :draft
    )

    # Emit event
    # EventLog.create(...)

    new_version
  end
end
