class Admin::InvoicesController < ApplicationController
  include Admin::Concerns::GenerateInvoice
  include CrudActions

  before_action :authenticate_user!
  before_action :ensure_admin!
  before_action :set_invoice, only: [ :show, :edit, :update, :issue, :void, :apply_payment, :download_pdf ]

  def index
    @invoices = Invoice.includes(:organization, :payments)
                      .order(created_at: :desc)
    # .page(params[:page])

    # Apply filters
    @invoices = @invoices.by_organization(params[:organization_id]) if params[:organization_id].present?
    @invoices = @invoices.where(status: params[:status]) if params[:status].present?
    @invoices = @invoices.past_due if params[:past_due] == "true"
    @invoices = @invoices.by_service_month(params[:service_month]) if params[:service_month].present?

    @organizations = Organization.order(:name)
  end

  def show
    @payments = @invoice.payments.order(created_at: :desc)
  end

  def new
    @invoice = Invoice.new
    @organizations = Organization.order(:name)
  end

  def create
    @invoice = Invoice.new(invoice_params)
    @organizations = Organization.order(:name)

    if @invoice.save
      redirect_to admin_invoice_path(@invoice), notice: "Invoice created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.order(:name)
  end

  def update
    @organizations = Organization.order(:name)

    if @invoice.update(invoice_params)
      redirect_to admin_invoice_path(@invoice), notice: "Invoice updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def issue
    if @invoice.draft?
      @invoice.mark_as_issued!
      redirect_to admin_invoice_path(@invoice), notice: "Invoice issued successfully."
    else
      redirect_to admin_invoice_path(@invoice), alert: "Only draft invoices can be issued."
    end
  end

  def void
    if @invoice.issued? || @invoice.partially_paid?
      @invoice.update!(status: :voided)
      redirect_to admin_invoice_path(@invoice), notice: "Invoice voided successfully."
    else
      redirect_to admin_invoice_path(@invoice), alert: "Only issued or partially paid invoices can be voided."
    end
  end

  def apply_payment
    amount = params[:amount].to_f
    payment_method = params[:payment_method]
    notes = params[:notes]

    if amount <= 0
      redirect_to admin_invoice_path(@invoice), alert: "Payment amount must be greater than 0."
      return
    end

    if amount > @invoice.amount_due
      redirect_to admin_invoice_path(@invoice), alert: "Payment amount cannot exceed amount due."
      return
    end

    begin
      @invoice.apply_payment!(
        amount,
        payment_method: payment_method,
        status: :succeeded,
        paid_at: Time.current,
        processed_by_user_id: current_user.id,
        notes: notes
      )

      redirect_to admin_invoice_path(@invoice), notice: "Payment applied successfully."
    rescue => e
      redirect_to admin_invoice_path(@invoice), alert: "Error applying payment: #{e.message}"
    end
  end

  def download_pdf
    pdf_binary = generate_invoice_pdf(@invoice)

    send_data pdf_binary,
              filename: "invoice-#{@invoice.id}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :organization_id,
      :invoice_type,
      :status,
      :issue_date,
      :due_date,
      :service_period_start,
      :service_period_end,
      :service_month,
      :currency,
      :subtotal,
      :total,
      :amount_paid,
      :amount_credited,
      :percent_of_revenue_snapshot,
      :collected_revenue_amount,
      :deductible_applied_claims_count,
      :deductible_fee_snapshot,
      :adjustments_total,
      :exception_type,
      :exception_reason,
      :exception_through,
      :exception_set_by_user_id,
      :exception_set_at,
      :notes_internal,
      :notes_client
    )
  end

  def ensure_admin!
    redirect_to root_path, alert: "Access denied." unless current_user&.admin?
  end
end
