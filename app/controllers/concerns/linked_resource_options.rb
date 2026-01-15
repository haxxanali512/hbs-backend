module LinkedResourceOptions
  extend ActiveSupport::Concern

  LINKED_RESOURCE_CONFIG = {
    "Encounter" => {
      klass: Encounter,
      method: :patient_encounters,
      label: ->(record) {
        date = record.date_of_service&.strftime("%m/%d/%Y") || "—"
        provider = record.provider&.full_name || "—"
        status = record.status.to_s.humanize
        "#{date} · #{provider} · #{status}"
      }
    },
    "Claim" => {
      klass: Claim,
      method: :patient_claims,
      label: ->(record) {
        date = record.encounter&.date_of_service&.strftime("%m/%d/%Y") || "—"
        provider = record.provider&.full_name || "—"
        status = record.status.to_s.humanize
        "Claim ##{record.id} · #{date} · #{provider} · #{status}"
      }
    },
    "Invoice" => {
      klass: Invoice,
      method: :patient_invoices,
      label: ->(record) {
        number = record.invoice_number.presence || "Invoice ##{record.id}"
        status = record.status.to_s.humanize
        "#{number} · #{status}"
      }
    },
    "Agreement" => {
      klass: Document,
      method: :patient_agreements,
      label: ->(record) {
        title = record.title.presence || "Agreement ##{record.id}"
        status = record.status.to_s.humanize
        "#{title} · #{status}"
      }
    }
  }.freeze

  PATIENT_SCOPED_RESOURCES = %w[Encounter Claim].freeze

  def linked_resource_options(resource_type, organization, patient_id)
    config = LINKED_RESOURCE_CONFIG[resource_type]
    return [] unless config

    records = config[:klass].public_send(config[:method], organization, patient_id)
    records.limit(100).map do |record|
      { id: record.id, label: config[:label].call(record) }
    end
  end

  def linked_resource_requires_patient?(resource_type)
    PATIENT_SCOPED_RESOURCES.include?(resource_type)
  end
end
