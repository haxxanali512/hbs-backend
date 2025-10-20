class Tenant::ActivationController < Tenant::BaseController
  before_action :authenticate_user!
  before_action :set_organization
  before_action :check_activation_status

  def index
    @steps = build_activation_steps(@current_organization)
  end
  def billing_setup
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  def update_billing
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing

    billing_attributes = billing_params.to_h
    case billing_attributes[:provider]
    when "stripe", "gocardless"
      billing_attributes[:billing_status] = "active"
    when "manual"
      billing_attributes[:billing_status] = "pending_approval"
    end

    if @billing.update(billing_attributes)
      # @current_organization.setup_billing!

      if @billing.active?
        onboarding_result = OnboardingFeeService.charge_onboarding_fee!(@current_organization)

        if onboarding_result[:success]
          @current_organization.billing_setup_complete!
          Rails.logger.info "Onboarding fee charged successfully for organization #{@current_organization.id}"
        else
          Rails.logger.error "Failed to charge onboarding fee for organization #{@current_organization.id}: #{onboarding_result[:error]}"
        end
      end

      # Send email notification for non-manual payment methods
      unless @billing.manual?
        OrganizationBillingMailer.billing_setup_completed(@billing).deliver_now
      end

      redirect_to tenant_activation_documents_path, notice: "Billing setup complete ✅"
    else
      render :billing_setup
    end
  end

  def compliance_setup
    OrganizationMailer.compliance_setup_required(@current_organization).deliver_now
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance
  end

  def update_compliance
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance
    if @compliance.update(compliance_params)
      if @compliance.gsa_signed_at.present? && @compliance.baa_signed_at.present?
        @current_organization.compliance_setup_complete!
        redirect_to tenant_activation_billing_path, notice: "Compliance verified! You can now proceed to billing setup."
      else
        redirect_to tenant_activation_compliance_path, notice: "Compliance verification required. Please verify your compliance information."
      end
    else
      render :compliance_setup
    end
  end

  def document_signing
    OrganizationMailer.document_signing_required(@current_organization).deliver_now
    @compliance = @organization.organization_compliance
  end

  def complete_document_signing
    @compliance = @organization.organization_compliance || @organization.build_organization_compliance

    if @compliance.update(terms_of_use: true, privacy_policy_accepted: true)
      @organization.documents_signing_complete!

      redirect_to tenant_activation_billing_path, notice: "Documents signed ✅"
    else
      @compliance = @organization.organization_compliance || @organization.build_organization_compliance
      render :document_signing
    end
  end

  def activate
    @organization.activate!

    OrganizationMailer.activation_completed(@organization).deliver_now

    redirect_to root_path, notice: "🎉 Your organization is now active!"
  end

  def activation_complete
    @organization = @current_organization
  end

  def save_stripe_card
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing

    # This will be handled by AJAX from the frontend
    render json: { success: true }
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
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  def send_agreement
    @compliance = @current_organization.organization_compliance || @current_organization.build_organization_compliance

    docusign_service = DocusignService.new
    result = docusign_service.send_agreement(@current_organization, current_user)

    if result[:success]
      @compliance.update!(
        gsa_envelope_id: result[:envelope_id],
        baa_envelope_id: result[:envelope_id],
        gsa_signed_at: nil, # Will be updated via webhook when signed
        baa_signed_at: nil  # Will be updated via webhook when signed
      )

      render json: {
        success: true,
        message: "GSA and BAA Agreement sent for signature",
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

    # If already signed, return cached status
    if @compliance.gsa_signed_at.present? && @compliance.baa_signed_at.present?
      Rails.logger.info "Agreement already signed, returning cached status"
      return render json: {
        success: true,
        results: {
          gsa: { success: true, status: "completed", envelope_id: @compliance.gsa_envelope_id },
          baa: { success: true, status: "completed", envelope_id: @compliance.baa_envelope_id }
        }
      }
    end

    docusign_service = DocusignService.new
    results = {}

    # Since we now use the same envelope for both GSA and BAA, check either envelope ID
    envelope_id = @compliance.gsa_envelope_id.present? ? @compliance.gsa_envelope_id : @compliance.baa_envelope_id

    if envelope_id.present?
      Rails.logger.info "Checking DocuSign status for envelope: #{envelope_id}"
      envelope_result = docusign_service.get_envelope_status(envelope_id)
      Rails.logger.info "DocuSign status response: #{envelope_result.inspect}"

      # If completed, update the database
      if envelope_result[:success] && envelope_result[:status] == "completed"
        Rails.logger.info "Agreement completed, updating database"
        @compliance.update!(
          gsa_signed_at: Time.current,
          baa_signed_at: Time.current
        )
      end

      # Return the same result for both GSA and BAA since they use the same envelope
      results[:gsa] = envelope_result
      results[:baa] = envelope_result
    else
      Rails.logger.info "No envelope ID found for organization #{@current_organization.id}"
    end

    render json: { success: true, results: results }
  end

  private

  def build_activation_steps(organization)
    status_value = organization.activation_status_before_type_cast

    steps_definitions = [
      { name: "Organization Created", key: :pending },
      { name: "Compliance Setup", key: :compliance_setup },
      { name: "Billing Setup", key: :billing_setup },
      { name: "Document Signing", key: :document_signing },
      { name: "Activation Complete", key: :activated }
    ]

    steps_definitions.map.with_index do |step, _index|
      step_index = Organization.activation_statuses[step[:key]]

      # First step ("Organization Created") is always completed once the org exists
      if step[:key] == :pending
        completed = true
        current   = status_value == Organization.activation_statuses[:compliance_setup] ||
                    (status_value.zero? && organization.persisted?)
      else
        completed = step_index < status_value
        current   = step_index == status_value
      end

      {
        name: step[:name],
        completed: completed,
        current: current
      }
    end
  end

  def set_organization
    @organization = current_user.organizations.first
    redirect_to root_path, alert: "No organization found" unless @organization
  rescue
    redirect_to root_path, alert: "No organization found"
  end

  def check_activation_status
    case @organization.activation_status
    when "pending"
      redirect_to tenant_activation_compliance_path unless action_name == "index" || action_name == "compliance_setup" || action_name == "update_compliance" || action_name == "send_agreement" || action_name == "check_docusign_status"
    when "billing_setup"
      redirect_to tenant_activation_billing_path unless action_name == "update_billing" || action_name == "billing_setup"
    when "document_signing"
      redirect_to tenant_activation_documents_path unless action_name == "complete_document_signing" || action_name == "document_signing"
    when "activated"
      redirect_to tenant_dashboard_path unless action_name == "activate" || action_name == "send_agreement"
    end
  end

  def billing_params
    params.require(:organization_billing).permit(:billing_status, :last_payment_date, :next_payment_due, :method_last4, :provider)
  end

  def compliance_params
    params.require(:organization_compliance).permit(:gsa_signed_at, :gsa_envelope_id, :baa_signed_at, :baa_envelope_id, :phi_access_locked_at, :data_retention_expires_at, :terms_of_use, :privacy_policy_accepted)
  end
end
