class Admin::PaymentsController < Admin::BaseController
  def index
    @payments = Payment.includes(:organization, :payer, :processed_by_user)
                       .order(created_at: :desc)

    if params[:organization_id].present?
      @payments = @payments.where(organization_id: params[:organization_id])
    end

    if params[:status].present?
      @payments = @payments.where(payment_status: params[:status])
    end

    if params[:payment_method].present?
      @payments = @payments.where(payment_method: params[:payment_method])
    end

    if params[:date_from].present?
      from = Date.parse(params[:date_from]) rescue nil
      if from
        @payments = @payments.where("payment_date >= ? OR (payment_date IS NULL AND created_at >= ?)", from, from)
      end
    end

    if params[:date_to].present?
      to = Date.parse(params[:date_to]) rescue nil
      if to
        @payments = @payments.where("payment_date <= ? OR (payment_date IS NULL AND created_at <= ?)", to, to)
      end
    end

    if params[:search].present?
      term = "%#{params[:search]}%"
      @payments = @payments.joins(:organization)
                           .left_joins(:payer)
                           .where(
                             "payments.remit_reference ILIKE ? OR payments.source_hash ILIKE ? OR organizations.name ILIKE ? OR payers.name ILIKE ?",
                             term, term, term, term
                           )
    end

    @pagy, @payments = pagy(@payments, items: 20)

    @search_placeholder = "Remit reference, payer, org, source hash..."
    @organization_options = Organization.order(:name)
    @status_options = Payment.payment_statuses.keys
    @custom_selects = [
      {
        param: :payment_method,
        label: "Method",
        options: [ [ "All Methods", "" ] ] + Payment.payment_methods.keys.map { |m| [ m.humanize, m ] }
      }
    ]
    @show_date_range = true
  end
end
