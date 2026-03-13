class Tenant::PaymentsController < Tenant::BaseController
  def index
    @payments = @current_organization.payments
      .includes(:payer)
      .order(payment_date: :desc, created_at: :desc)

    apply_filters
    @pagy, @payments = pagy(@payments, items: 20)
    load_filter_options
  end

  def export
    unless @current_organization.tier_percentage == 9.0
      redirect_to tenant_payments_path, alert: "CSV export is not available for your plan tier."
      return
    end

    payments = @current_organization.payments
      .includes(:payer)
      .order(payment_date: :desc, created_at: :desc)

    apply_filters_to(payments) do |filtered|
      csv_data = generate_csv(filtered)
      send_data csv_data,
                filename: "payments_#{Date.current.strftime('%Y%m%d')}.csv",
                type: "text/csv",
                disposition: "attachment"
    end
  end

  private

  def apply_filters
    @payments = filter_payments(@payments)
  end

  def apply_filters_to(scope)
    yield filter_payments(scope)
  end

  def filter_payments(scope)
    scope = scope.where(payment_status: params[:status]) if params[:status].present?
    scope = scope.where(payment_method: params[:payment_method]) if params[:payment_method].present?
    scope = scope.where(payer_id: params[:payer_id]) if params[:payer_id].present?

    if params[:date_from].present?
      from = Date.parse(params[:date_from]) rescue nil
      scope = scope.where("payment_date >= ? OR (payment_date IS NULL AND payments.created_at >= ?)", from, from) if from
    end

    if params[:date_to].present?
      to = Date.parse(params[:date_to]) rescue nil
      scope = scope.where("payment_date <= ? OR (payment_date IS NULL AND payments.created_at <= ?)", to, to) if to
    end

    if params[:search].present?
      term = "%#{params[:search]}%"
      scope = scope.left_joins(:payer).where(
        "payments.remit_reference ILIKE ? OR payers.name ILIKE ?",
        term, term
      )
    end

    scope
  end

  def load_filter_options
    @search_placeholder = "Remit reference, payer name..."
    @payer_options = Payer.where(id: @current_organization.payments.select(:payer_id).distinct)
                         .order(:name)
    @status_options = Payment.payment_statuses.keys.map { |s| [s.humanize, s] }
    @use_status_for_action_type = true
    @custom_selects = [
      {
        param: :payment_method,
        label: "Service Type",
        options: [["All Types", ""]] + Payment.payment_methods.keys.map { |m| [m.humanize, m] }
      },
      {
        param: :payer_id,
        label: "Payer",
        options: [["All Payers", ""]] + (@payer_options&.map { |p| [p.name, p.id] } || [])
      }
    ]
    @show_date_range = true
    @can_export = @current_organization.tier_percentage == 9.0
  end

  def generate_csv(payments)
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << [
        "Payment Date",
        "Payer",
        "Remit Reference",
        "Amount",
        "Applied",
        "Remaining",
        "Status",
        "Method",
        "Created At"
      ]
      payments.find_each do |payment|
        csv << [
          (payment.payment_date || payment.created_at)&.strftime("%m/%d/%Y"),
          payment.payer&.name || "—",
          payment.remit_reference || "—",
          payment.amount_total || payment.amount || 0,
          payment.applied_total,
          payment.remaining_amount,
          payment.payment_status&.humanize,
          payment.payment_method&.humanize,
          payment.created_at&.strftime("%m/%d/%Y %H:%M")
        ]
      end
    end
  end
end
