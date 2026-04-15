class Admin::PrescriptionsController < Admin::BaseController
  include PrescriptionsExpirationExportable

  def index
    @prescriptions = base_scope
    apply_filters_to(@prescriptions) do |filtered|
      @prescriptions = filtered
    end
    apply_search
    apply_sort

    @pagy, @prescriptions = pagy(@prescriptions.distinct, items: 20)
    load_filter_options
  end

  def export
    scope = base_scope
    apply_filters_to(scope) do |filtered|
      @prescriptions = filtered
    end
    apply_search
    apply_sort

    csv_data = prescriptions_to_csv(@prescriptions.distinct)
    send_data csv_data,
              filename: prescription_export_filename(params[:expiration_filter]),
              type: "text/csv",
              disposition: "attachment"
  end

  def show
    @prescription = Prescription.kept
      .includes(:patient, :organization, :provider, :diagnosis_codes, :documents_attachments, :documents_blobs)
      .find(params[:id])
  end

  private

  def base_scope
    Prescription.kept
      .includes(:patient, :organization, :provider)
      .left_joins(documents_attachments: :blob)
  end

  def apply_filters_to(scope)
    @prescriptions = scope
    apply_filters
    yield @prescriptions
  end

  def apply_filters
    if params[:organization_id].present?
      @prescriptions = @prescriptions.where(organization_id: params[:organization_id])
    end

    case params[:status]
    when "active"
      @prescriptions = @prescriptions.where(archived: false, expired: false)
    when "expired"
      @prescriptions = @prescriptions.where(expired: true)
    when "archived"
      @prescriptions = @prescriptions.where(archived: true)
    when "expiring"
      @prescriptions = @prescriptions.where(archived: false, expired: false)
        .where("prescriptions.expires_on BETWEEN ? AND ?", Date.current, Date.current + 30.days)
    end

    if params[:date_from].present?
      @prescriptions = @prescriptions.where("prescriptions.date_written >= ?", params[:date_from])
    end
    if params[:date_to].present?
      @prescriptions = @prescriptions.where("prescriptions.date_written <= ?", params[:date_to])
    end

    if params[:linked_to_encounter].present?
      linked_ids = Encounter.kept.where.not(prescription_id: nil).select(:prescription_id)
      if params[:linked_to_encounter] == "yes"
        @prescriptions = @prescriptions.where(id: linked_ids)
      elsif params[:linked_to_encounter] == "no"
        @prescriptions = @prescriptions.where.not(id: linked_ids)
      end
    end

    if params[:file_present].present?
      if params[:file_present] == "yes"
        @prescriptions = @prescriptions.where.not(active_storage_attachments: { id: nil })
      elsif params[:file_present] == "no"
        @prescriptions = @prescriptions.where(active_storage_attachments: { id: nil })
      end
    end

    @prescriptions = apply_expiration_filter_to_scope(@prescriptions, params[:expiration_filter])
  end

  def apply_search
    return if params[:search].blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].strip)}%"
    @prescriptions = @prescriptions
      .left_joins(:patient, :organization)
      .left_joins(documents_attachments: :blob)
      .where(
        "patients.first_name ILIKE :q OR patients.last_name ILIKE :q OR organizations.name ILIKE :q OR prescriptions.id::text ILIKE :q OR prescriptions.title ILIKE :q OR active_storage_blobs.filename ILIKE :q",
        q: q
      )
  end

  def apply_sort
    case params[:sort]
    when "date_asc"
      @prescriptions = @prescriptions.order(date_written: :asc, created_at: :asc)
    when "date_desc", nil, ""
      @prescriptions = @prescriptions.order(date_written: :desc, created_at: :desc)
    when "patient_asc"
      @prescriptions = @prescriptions.joins(:patient).order("patients.last_name ASC, patients.first_name ASC")
    when "patient_desc"
      @prescriptions = @prescriptions.joins(:patient).order("patients.last_name DESC, patients.first_name DESC")
    when "org_asc"
      @prescriptions = @prescriptions.joins(:organization).order("organizations.name ASC")
    when "org_desc"
      @prescriptions = @prescriptions.joins(:organization).order("organizations.name DESC")
    else
      @prescriptions = @prescriptions.order(date_written: :desc, created_at: :desc)
    end
  end

  def load_filter_options
    @organizations = Organization.kept.order(:name)
    @organization_options = Organization.kept.order(:name)
    @status_options = [
      ["Active", "active"],
      ["Expiring Soon", "expiring"],
      ["Expired", "expired"],
      ["Archived", "archived"]
    ]
    @sort_options = [
      ["Date written (newest)", "date_desc"],
      ["Date written (oldest)", "date_asc"],
      ["Patient name (A-Z)", "patient_asc"],
      ["Patient name (Z-A)", "patient_desc"],
      ["Organization (A-Z)", "org_asc"],
      ["Organization (Z-A)", "org_desc"]
    ]
    @search_placeholder = "Patient, organization, prescription ID, filename..."
    @custom_selects = [
      {
        param: :linked_to_encounter,
        label: "Linked to Encounter",
        options: [["All", ""], ["Yes", "yes"], ["No", "no"]]
      },
      {
        param: :file_present,
        label: "File Present",
        options: [["All", ""], ["Yes", "yes"], ["No", "no"]]
      },
      {
        param: :expiration_filter,
        label: "Expiration Status",
        options: [
          ["All", ""],
          ["Already Expired", "expired"],
          ["Expiring in <= 30 Days", "30"],
          ["Expiring in <= 60 Days", "60"],
          ["Expiring in <= 90 Days", "90"],
          ["Expiring in <= 120 Days", "120"]
        ]
      }
    ]
  end

end

