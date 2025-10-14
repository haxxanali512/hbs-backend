class Tenant::ActivationController < Tenant::BaseController
  before_action :authenticate_user!
  before_action :set_organization
  before_action :check_activation_status
  after_action :verify_authorized, except: [ :index ]

  def index
    authorize :activation, :index?
    # Overview page - show progress and next steps
    @steps = [
      { name: "Organization Created", completed: true, current: false },
      { name: "Billing Setup", completed: @organization.billing_setup? || @organization.compliance_setup? || @organization.document_signing? || @organization.activated?, current: @organization.pending? },
      { name: "Compliance Setup", completed: @organization.compliance_setup? || @organization.document_signing? || @organization.activated?, current: @organization.billing_setup? },
      { name: "Document Signing", completed: @organization.document_signing? || @organization.activated?, current: @organization.compliance_setup? },
      { name: "Activation Complete", completed: @organization.activated?, current: @organization.document_signing? }
    ]
  end

  def billing_setup
    authorize :activation, :billing_setup?
    @billing = @organization.organization_billing || @organization.build_organization_billing

    # Send email when billing setup step is first reached
    if @organization.pending?
      OrganizationMailer.billing_setup_required(@organization).deliver_now
    end
  end

  def update_billing
    authorize :activation, :billing_setup?
    @billing = @organization.organization_billing || @organization.build_organization_billing

    if @billing.update(billing_params)
      @organization.setup_billing!

      # Send email notification for non-manual payment methods
      unless @billing.manual?
        OrganizationBillingMailer.billing_setup_completed(@billing).deliver_now
      end

      # Send email for next step (compliance setup)
      OrganizationMailer.compliance_setup_required(@organization).deliver_now

      redirect_to activation_compliance_path, notice: "Billing setup complete ✅"
    else
      render :billing_setup
    end
  end

  def compliance_setup
    authorize :activation, :compliance_setup?
    @compliance = @organization.organization_compliance || @organization.build_organization_compliance
  end

  def update_compliance
    authorize :activation, :compliance_setup?
    @compliance = @organization.organization_compliance || @organization.build_organization_compliance

    if @compliance.update(compliance_params)
      @organization.setup_compliance!

      # Send email for next step (document signing)
      OrganizationMailer.document_signing_required(@organization).deliver_now

      redirect_to activation_document_signing_path, notice: "Compliance verified ✅"
    else
      render :compliance_setup
    end
  end

  def document_signing
    authorize :activation, :document_signing?
    @compliance = @organization.organization_compliance
  end

  def complete_document_signing
    authorize :activation, :document_signing?
    # In a real implementation, this would integrate with DocuSign or similar
    # For now, we'll simulate document signing completion
    @organization.sign_documents!

    # Send email for next step (activation complete)
    OrganizationMailer.organization_activated(@organization).deliver_now

    redirect_to activation_complete_path, notice: "Documents signed ✅"
  end

  def complete
    authorize :activation, :complete?
    # Show success page
  end

  def activate
    authorize :activation, :activate?
    @organization.activate!

    # Send final activation completed email
    OrganizationMailer.activation_completed(@organization).deliver_now

    redirect_to root_path, notice: "🎉 Your organization is now active!"
  end

  private

  def set_organization
    @organization = current_user.organizations.first
    redirect_to root_path, alert: "No organization found" unless @organization
  rescue
    redirect_to root_path, alert: "No organization found"
  end

  def check_activation_status
    # Redirect to appropriate step based on current state
    case @organization.activation_status
    when "pending"
      redirect_to activation_billing_path unless action_name == "index" || action_name == "billing_setup" || action_name == "update_billing"
    when "billing_setup"
      # Check if billing is approved before allowing compliance setup
      if @organization.organization_billing&.pending_approval?
        flash[:alert] = "Your billing setup is pending approval. Please wait for a super admin to review your request."
        redirect_to activation_billing_path unless action_name == "billing_setup" || action_name == "update_billing" || action_name == "manual_payment"
      elsif @organization.organization_billing&.cancelled?
        flash[:alert] = "Your billing setup was rejected. Please resubmit your payment information."
        redirect_to activation_billing_path unless action_name == "billing_setup" || action_name == "update_billing" || action_name == "manual_payment"
      else
        redirect_to activation_compliance_path unless action_name == "compliance_setup" || action_name == "update_compliance"
      end
    when "compliance_setup"
      redirect_to activation_document_signing_path unless action_name == "document_signing" || action_name == "complete_document_signing"
    when "document_signing"
      redirect_to activation_complete_path unless action_name == "complete" || action_name == "activate"
    when "activated"
      redirect_to root_path unless action_name == "complete"
    end
  end

  def manual_payment
    # Create or update organization billing with manual status
    billing = @organization.organization_billing || @organization.build_organization_billing
    billing.update!(
      billing_status: "pending_approval",
      provider: "manual"
    )

    # Send notification to super admins
    OrganizationBillingMailer.manual_payment_request(billing).deliver_now

    render json: {
      success: true,
      message: "Manual payment request submitted successfully. A super admin will review and approve your billing setup."
    }
  rescue => e
    Rails.logger.error "Manual payment submission failed: #{e.message}"
    render json: {
      success: false,
      error: "Failed to submit manual payment request. Please try again."
    }, status: :unprocessable_entity
  end

  def billing_params
    params.require(:organization_billing).permit(:billing_status, :last_payment_date, :next_payment_due, :method_last4, :provider)
  end

  def compliance_params
    params.require(:organization_compliance).permit(:gsa_signed_at, :gsa_envelope_id, :baa_signed_at, :baa_envelope_id, :phi_access_locked_at, :data_retention_expires_at)
  end
end
