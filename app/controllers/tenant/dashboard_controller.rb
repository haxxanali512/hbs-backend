class Tenant::DashboardController < Tenant::BaseController
  before_action :check_activation_status, only: [ :activation, :billing_setup, :update_billing, :manual_payment, :compliance_setup, :update_compliance, :document_signing, :complete_document_signing, :activation_complete, :activate ]

  def index
    if @current_organization.activated?
      # Show full dashboard with sidebar
      @organizations_count = Organization.count
      @active_organizations = Organization.where(activation_status: :activated).count
      @total_users = User.count
      @pending_billings = OrganizationBilling.pending_approval.count
      @recent_organizations = Organization.order(created_at: :desc).limit(5)
      @recent_users = User.order(created_at: :desc).limit(5)

      # Calculate growth metrics
      @organizations_growth = calculate_growth(Organization, 30.days.ago)
      @users_growth = calculate_growth(User, 30.days.ago)

      # Rails will automatically render index.html.erb
    else
      # Redirect non-activated organizations to activation overview
      redirect_to tenant_activation_path
    end
  end

  # Activation methods (moved from Tenant::ActivationController)
  def activation
    # Overview page - show progress and next steps
    @steps = [
      { name: "Organization Created", completed: true, current: false },
      { name: "Billing Setup", completed: @current_organization.billing_setup? || @current_organization.compliance_setup? || @current_organization.document_signing? || @current_organization.activated?, current: @current_organization.pending? },
      { name: "Compliance Setup", completed: @current_organization.compliance_setup? || @current_organization.document_signing? || @current_organization.activated?, current: @current_organization.billing_setup? },
      { name: "Document Signing", completed: @current_organization.document_signing? || @current_organization.activated?, current: @current_organization.compliance_setup? },
      { name: "Activation Complete", completed: @current_organization.activated?, current: @current_organization.document_signing? }
    ]
  end

  def billing_setup
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing

    # Send email when billing setup step is first reached
    if @current_organization.pending?
      OrganizationMailer.billing_setup_required(@current_organization).deliver_now
    end
  end

  def update_billing
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing

    # Debug: Log the parameters being sent
    Rails.logger.debug "Billing params: #{billing_params.inspect}"
    Rails.logger.debug "Raw params: #{params[:organization_billing].inspect}"

    # Set billing status based on provider - users cannot manually set this
    billing_attributes = billing_params.to_h
    case billing_attributes[:provider]
    when "stripe", "gocardless"
      # For payment providers, set as active (will be updated by webhook events)
      billing_attributes[:billing_status] = "active"
    when "manual"
      # For manual payments, set as pending approval (requires admin review)
      billing_attributes[:billing_status] = "pending_approval"
    end

    if @billing.update(billing_attributes)
      @current_organization.setup_billing!

      # Send email notification for non-manual payment methods
      unless @billing.manual?
        OrganizationBillingMailer.billing_setup_completed(@billing).deliver_now
      end

      # Send email for next step (compliance setup)
      OrganizationMailer.compliance_setup_required(@current_organization).deliver_now

      redirect_to tenant_activation_compliance_path, notice: "Billing setup complete ✅"
    else
      render :billing_setup
    end
  end

  def compliance_setup
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance
  end

  def update_compliance
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance

    if @compliance.update(compliance_params)
      @current_organization.setup_compliance!

      # Send email for next step (document signing)
      OrganizationMailer.document_signing_required(@current_organization).deliver_now

      redirect_to tenant_activation_documents_path, notice: "Compliance verified ✅"
    else
      render :compliance_setup
    end
  end

  def document_signing
    @compliance = @current_organization.organization_compliance
  end

  def complete_document_signing
    # In a real implementation, this would integrate with DocuSign or similar
    # For now, we'll simulate document signing completion
    @current_organization.sign_documents!

    # Send email for next step (activation complete)
    OrganizationMailer.organization_activated(@current_organization).deliver_now

    redirect_to tenant_activation_complete_path, notice: "Documents signed ✅"
  end

  def activation_complete
    @organization = @current_organization
  end

  def activate
    @current_organization.activate

    # Send final activation completed email
    OrganizationMailer.activation_completed(@current_organization).deliver_now

    redirect_to tenant_root_path, notice: "🎉 Your organization is now active!"
  end

  def manual_payment
    # Create or update organization billing with manual status
    billing = @current_organization.organization_billing || @current_organization.build_organization_billing
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

  def stripe_card
    # Show the Stripe card collection page
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  def save_stripe_card
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing

    # This will be handled by AJAX from the frontend
    render json: { success: true }
  end

  def send_gsa_agreement
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance

    docusign_service = DocusignService.new
    result = docusign_service.send_gsa_agreement(@current_organization, current_user)
    byebug
    if result[:success]
      @compliance.update!(
        gsa_envelope_id: result[:envelope_id],
        gsa_signed_at: nil # Will be updated via webhook when signed
      )

      render json: {
        success: true,
        message: "GSA Agreement sent for signature",
        envelope_id: result[:envelope_id]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  def send_baa_agreement
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance

    docusign_service = DocusignService.new
    result = docusign_service.send_baa_agreement(@current_organization, current_user)

    if result[:success]
      @compliance.update!(
        baa_envelope_id: result[:envelope_id],
        baa_signed_at: nil # Will be updated via webhook when signed
      )

      render json: {
        success: true,
        message: "BAA Agreement sent for signature",
        envelope_id: result[:envelope_id]
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  def check_docusign_status
    @compliance = @current_organization.organization_compliance

    return render json: { success: false, error: "No compliance record found" } unless @compliance

    docusign_service = DocusignService.new
    results = {}

    if @compliance.gsa_envelope_id.present?
      gsa_result = docusign_service.get_envelope_status(@compliance.gsa_envelope_id)
      results[:gsa] = gsa_result
    end

    if @compliance.baa_envelope_id.present?
      baa_result = docusign_service.get_envelope_status(@compliance.baa_envelope_id)
      results[:baa] = baa_result
    end

    render json: { success: true, results: results }
  end

  private

  def check_activation_status
    return if @current_organization.activated?

    # Redirect to appropriate step based on current state
    case @current_organization.activation_status
    when "pending"
      redirect_to tenant_activation_billing_path unless action_name == "index" || action_name == "activation" || action_name == "billing_setup" || action_name == "update_billing"
    when "billing_setup"
      # Check if billing is approved before allowing compliance setup
      if @current_organization.organization_billing&.pending_approval?
        flash[:alert] = "Your billing setup is pending approval. Please wait for a super admin to review your request."
        redirect_to tenant_activation_billing_path unless action_name == "billing_setup" || action_name == "update_billing" || action_name == "manual_payment"
      elsif @current_organization.organization_billing&.cancelled?
        flash[:alert] = "Your billing setup was rejected. Please resubmit your payment information."
        redirect_to tenant_activation_billing_path unless action_name == "billing_setup" || action_name == "update_billing" || action_name == "manual_payment"
      else
        redirect_to tenant_activation_compliance_path unless action_name == "compliance_setup" || action_name == "update_compliance"
      end
    when "compliance_setup"
      redirect_to tenant_activation_documents_path unless action_name == "document_signing" || action_name == "complete_document_signing"
    when "document_signing"
      redirect_to tenant_activation_complete_path unless action_name == "activation_complete" || action_name == "activate"
    when "activated"
      # No redirect needed - activated organizations can access all actions
    end
  end

  def calculate_growth(model, since)
    total = model.count
    recent = model.where("created_at > ?", since).count
    return 0 if total == 0

    ((recent.to_f / total) * 100).round(1)
  end

  def billing_params
    params.require(:organization_billing).permit(:last_payment_date, :next_payment_due, :method_last4, :provider)
  end

  def compliance_params
    params.require(:organization_compliance).permit(:gsa_signed_at, :gsa_envelope_id, :baa_signed_at, :baa_envelope_id, :phi_access_locked_at, :data_retention_expires_at)
  end
end
