class Tenant::OrganizationSettingsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_organization_setting, only: [ :show, :edit, :update ]

  def show
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
      feature_entitlements: {}
    )
  end
end
