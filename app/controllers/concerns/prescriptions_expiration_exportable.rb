module PrescriptionsExpirationExportable
  extend ActiveSupport::Concern

  private

  def apply_expiration_filter_to_scope(scope, filter_value)
    value = filter_value.to_s
    return scope if value.blank?

    scope = scope.where.not(expires_on: nil)
    today = Time.zone.today

    if value == "expired"
      scope.where("prescriptions.expires_on < ?", today)
    elsif %w[30 60 90 120].include?(value)
      days = value.to_i
      scope.where("prescriptions.expires_on BETWEEN ? AND ?", today, today + days.days)
    else
      scope
    end
  end

  def prescription_export_filename(filter_value)
    filter = filter_value.presence || "all"
    "prescriptions_export_#{filter}_#{Time.zone.today.strftime('%Y%m%d')}.csv"
  end

  def prescriptions_to_csv(scope)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [
        "Patient Name",
        "Date of Birth",
        "Prescription ID",
        "Referring Provider Name",
        "Diagnosis / Description",
        "Date Written",
        "Expiration Date",
        "Days Until Expiration",
        "Status"
      ]

      scope.find_each do |prescription|
        days_until_expiration = prescription.expires_on.present? ? (prescription.expires_on - Time.zone.today).to_i : nil
        diagnosis = prescription.diagnosis_codes.limit(5).pluck(:code).join(", ")
        diagnosis_description = [diagnosis.presence, prescription.title.presence].compact.join(" | ")

        status =
          if prescription.archived?
            "Archived"
          elsif prescription.expired?
            "Expired"
          else
            "Active"
          end

        csv << [
          prescription.patient&.full_name || "—",
          prescription.patient&.dob&.strftime("%m/%d/%Y"),
          prescription.id,
          prescription.provider&.full_name || "—",
          diagnosis_description.presence || "—",
          prescription.date_written&.strftime("%m/%d/%Y"),
          prescription.expires_on&.strftime("%m/%d/%Y"),
          days_until_expiration,
          status
        ]
      end
    end
  end
end
