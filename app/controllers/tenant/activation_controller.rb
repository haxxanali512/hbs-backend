class Tenant::ActivationController < Tenant::BaseController
  include ActivationStepsConcern

  # before_action :authenticate_user!
  # before_action :set_organization
  before_action :check_activation_status

  def index
    @steps = build_activation_steps(@current_organization)
    @organization = @current_organization
  end

  def billing_setup
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  def update_billing
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
    selected_provider = params.dig(:organization_billing, :provider).presence || @billing.provider || "stripe"

    case selected_provider
    when "stripe"
      @billing.provider = :stripe
      @billing.billing_status = :active
      unless @billing.stripe_customer_id.present? && @billing.stripe_payment_method_id.present?
        flash.now[:alert] = "Please add a Stripe card before continuing."
        render :billing_setup, status: :unprocessable_entity
        return
      end
    when "gocardless"
      @billing.provider = :gocardless
      @billing.billing_status = :active
      unless @billing.gocardless_customer_id.present? && @billing.gocardless_mandate_id.present?
        flash.now[:alert] = "Please authorize a GoCardless mandate before continuing."
        render :billing_setup, status: :unprocessable_entity
        return
      end
    else
      flash.now[:alert] = "Unsupported payment provider selected."
      render :billing_setup, status: :unprocessable_entity
      return
    end

    onboarding_result = OnboardingFeeService.charge_onboarding_fee!(@current_organization)
    unless onboarding_result[:success]
      flash.now[:alert] = "Payment failed: #{onboarding_result[:error]}"
      render :billing_setup, status: :unprocessable_entity
      return
    end

    @billing.last_payment_date = Time.current
    @billing.next_payment_due ||= 1.month.from_now
    @billing.save!

    @current_organization.terms_agreement_complete! if @current_organization.billing_setup?
    OrganizationBillingMailer.billing_setup_completed(@billing).deliver_now

    redirect_to tenant_activation_complete_path, notice: "Payment received. You can now activate your organization."
  end

  def compliance_setup
    @organization = @current_organization
    @contact = @organization.organization_contact || @organization.build_organization_contact
    @identifier = @organization.organization_identifier || @organization.build_organization_identifier
    @owner = @organization.owner
  end

  def update_compliance
    @organization = @current_organization
    @contact = @organization.organization_contact || @organization.build_organization_contact
    @identifier = @organization.organization_identifier || @organization.build_organization_identifier
    @owner = @organization.owner

    ActiveRecord::Base.transaction do
      @organization.update!(name: intake_params[:company_name])
      @owner.update!(
        first_name: parsed_owner_name.first.presence || @owner.first_name,
        last_name: parsed_owner_name.second.presence || @owner.last_name,
        email: intake_params[:primary_email]
      )
      @contact.update!(
        address_line1: intake_params[:business_address],
        phone: intake_params[:phone_number],
        email: intake_params[:primary_email],
        contact_type: (@contact.contact_type || 0)
      )
      @identifier.update!(
        tax_identification_number: intake_params[:ein],
        tax_id_type: :ein,
        npi: intake_params[:npi],
        npi_type: (@identifier.npi_type || :type_2)
      )

      validate_intake_identifiers!
      @organization.compliance_setup_complete! if @organization.pending?
    end

    redirect_to tenant_activation_documents_path, notice: "Business information saved."
  rescue => e
    flash.now[:alert] = e.message
    render :compliance_setup, status: :unprocessable_entity
  end

  def document_signing
    @organization = @current_organization
    @compliance = @organization.organization_compliance || @organization.build_organization_compliance
  end

  def complete_document_signing
    @organization = @current_organization
    @compliance = @organization.organization_compliance || @organization.build_organization_compliance

    unless ActiveModel::Type::Boolean.new.cast(params[:agreement_accepted])
      flash.now[:alert] = "You must review and accept the contract."
      render :document_signing, status: :unprocessable_entity
      return
    end

    selected_tier = params[:selected_tier].to_s
    unless %w[6% 7% 8% 9%].include?(selected_tier)
      flash.now[:alert] = "Please select a billing tier."
      render :document_signing, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @organization.update!(tier: selected_tier, referral_code: params[:referral_code].presence)
      @compliance.update!(
        terms_of_use: true,
        privacy_policy_accepted: true,
        contract_accepted_at: Time.current,
        contract_version: "activation_contract_v1"
      )
      @organization.billing_setup_complete! if @organization.compliance_setup?
    end

    redirect_to tenant_activation_billing_path, notice: "Contract accepted and tier selected."
  end

  def activate
    @organization = @current_organization
    @organization.activate!

    OrganizationMailer.activation_completed(@organization).deliver_now

    redirect_to tenant_dashboard_path, notice: "🎉 Your organization is now active!"
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
    render json: {
      success: false,
      error: "Manual payment is not supported for onboarding. Please pay with a Stripe card."
    }
  end

  def send_agreement
    render json: { success: false, error: "DocuSign is not used in this onboarding flow." }, status: :unprocessable_entity
  end

  def check_docusign_status
    render json: { success: true, results: {} }
  end

  def stripe_card
    @billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  private

  def build_activation_steps(organization)
    status_value = organization.activation_status_before_type_cast

    steps_definitions = [
      { name: "Business Information", key: :pending },
      { name: "Contract & Tier", key: :compliance_setup },
      { name: "Onboarding Payment", key: :billing_setup },
      { name: "Ready To Activate", key: :terms_agreement },
      { name: "Activation Complete", key: :activated }
    ]

    steps_definitions.map.with_index do |step, _index|
      step_index = Organization.activation_statuses[step[:key]]

      # First step is current while status is pending
      if step[:key] == :pending
        completed = status_value > Organization.activation_statuses[:pending]
        current   = status_value == Organization.activation_statuses[:pending] && organization.persisted?
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
    redirect_to tenant_dashboard_path, alert: "No organization found" unless @organization
  rescue
    redirect_to tenant_dashboard_path, alert: "No organization found"
  end

  def check_activation_status
    # Use @current_organization (set by set_tenant_context); @organization is set in individual actions
    org = @current_organization
    return redirect_to new_user_session_path, alert: "No organization context available." if org.nil?
    # Flow:
    # pending => business information
    # compliance_setup => contract/tier/referral
    # billing_setup => Stripe payment
    # terms_agreement => activation ready
    case org.activation_status
    when "pending"
      redirect_to tenant_activation_compliance_path unless action_name == "index" || action_name == "compliance_setup" || action_name == "update_compliance"
    when "compliance_setup"
      redirect_to tenant_activation_documents_path unless action_name == "index" || action_name == "document_signing" || action_name == "complete_document_signing"
    when "billing_setup"
      redirect_to tenant_activation_billing_path unless action_name == "index" || action_name == "billing_setup" || action_name == "update_billing" || action_name == "stripe_card" || action_name == "save_stripe_card"
    when "terms_agreement"
      redirect_to tenant_activation_complete_path unless action_name == "index" || action_name == "activation_complete" || action_name == "activate"
    when "activated"
      redirect_to tenant_dashboard_path unless action_name == "activate"
    end
  end

  def intake_params
    params.require(:intake).permit(:company_name, :owner_name, :primary_email, :phone_number, :business_address, :ein, :npi)
  end

  def parsed_owner_name
    intake_params[:owner_name].to_s.split(/\s+/, 2)
  end

  def validate_intake_identifiers!
    raise "EIN must be 9 digits." unless intake_params[:ein].to_s.match?(/\A\d{9}\z/)
    raise "NPI must be 10 digits." unless intake_params[:npi].to_s.match?(/\A\d{10}\z/)
  end
end
