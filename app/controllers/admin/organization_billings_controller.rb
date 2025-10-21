class Admin::OrganizationBillingsController < Admin::BaseController
  include Pagy::Frontend

  before_action :set_organization_billing, only: [ :show, :approve, :reject ]

  def index
    @all_billings = OrganizationBilling.includes(:organization).order(created_at: :desc)
    @all_billings = @all_billings.where(billing_status: params[:status]) if params[:status].present?
    @all_billings = @all_billings.where(provider: params[:provider]) if params[:provider].present?
    @all_billings = @all_billings.joins(:organization).where("organizations.name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    @pagy, @all_billings = pagy(@all_billings, items: 20)
    @pending_billings = OrganizationBilling.pending_approval.includes(:organization)
  end

  def show
    @organization = @organization_billing.organization
  end

  def approve
    @organization_billing.update!(
      billing_status: :active,
      last_payment_date: Time.current
    )

    # Update organization activation status to proceed to next step
    @organization_billing.organization.billing_setup_complete! if @organization_billing.organization.activation_status == "billing_setup"

    # Send approval email to organization owner
    OrganizationBillingMailer.manual_payment_approved(@organization_billing).deliver_now

    flash[:success] = "Billing setup approved successfully. Organization can now proceed to compliance setup."
    redirect_to admin_organization_billings_path
  end

  def reject
    @organization_billing.update!(
      billing_status: :cancelled
    )

    # Send rejection email to organization owner
    OrganizationBillingMailer.manual_payment_rejected(@organization_billing).deliver_now

    flash[:alert] = "Billing setup rejected. Organization will need to resubmit their payment information."
    redirect_to admin_organization_billings_path
  end

  private

  def set_organization_billing
    @organization_billing = OrganizationBilling.find(params[:id])
  end
end
