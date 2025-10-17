class Tenant::InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_current_organization
  before_action :set_invoice, only: [ :show, :pay ]

  def index
    @invoices = @current_organization.invoices
                                   .includes(:payments)
                                   .order(created_at: :desc)
                                   .page(params[:page])

    # Apply filters
    @invoices = @invoices.where(status: params[:status]) if params[:status].present?
    @invoices = @invoices.past_due if params[:past_due] == "true"
    @invoices = @invoices.by_service_month(params[:service_month]) if params[:service_month].present?
  end

  def show
    @payments = @invoice.payments.order(created_at: :desc)
  end

  def pay
    # Redirect to payment flow based on organization's payment provider
    if @current_organization.organization_billing&.provider == "stripe"
      redirect_to new_stripe_payment_path(invoice_id: @invoice.id)
    elsif @current_organization.organization_billing&.provider == "gocardless"
      redirect_to new_gocardless_payment_path(invoice_id: @invoice.id)
    else
      redirect_to tenant_invoice_path(@invoice), alert: "No payment method configured. Please contact support."
    end
  end

  private

  def set_invoice
    @invoice = @current_organization.invoices.find(params[:id])
  end
end
