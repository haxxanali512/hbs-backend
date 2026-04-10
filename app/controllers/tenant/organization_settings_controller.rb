class Tenant::OrganizationSettingsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_organization_setting, only: [ :show, :edit, :update, :update_billing_method ]

  def show
    @organization_billing = @current_organization.organization_billing || @current_organization.build_organization_billing
  end

  def edit
    @organization = @current_organization
  end

  def update
    if @organization_setting.update(settings_params)
      redirect_to tenant_organization_setting_path, notice: "Organization settings updated successfully."
    else
      @organization = @current_organization
      render :edit, status: :unprocessable_entity
    end
  end

  def update_billing_method
    billing = @current_organization.organization_billing || @current_organization.build_organization_billing
    provider = params[:provider].to_s

    case provider
    when "manual"
      billing.update!(
        provider: :manual,
        billing_status: :pending_approval
      )
      OrganizationBillingMailer.manual_payment_request(billing).deliver_now
      redirect_to tenant_organization_setting_path, notice: "Manual billing request submitted successfully."
    else
      redirect_to tenant_organization_setting_path, alert: "Unsupported billing provider selection."
    end
  rescue => e
    redirect_to tenant_organization_setting_path, alert: "Unable to update billing method: #{e.message}"
  end

  private

  def set_organization_setting
    @organization_setting = @current_organization.organization_setting || @current_organization.create_organization_setting
  end

  def settings_params
    params.require(:organization_setting).permit(
      :mrn_enabled,
      :mrn_prefix,
      :mrn_sequence,
      :mrn_format,
      :time_zone,
      feature_entitlements: {}
    )
  end
end
