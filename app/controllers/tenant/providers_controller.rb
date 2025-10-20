
class Tenant::ProvidersController < Tenant::BaseController
  before_action :set_provider, only: [ :show, :edit, :update, :destroy ]

  def index
    @providers = @current_organization.providers
  end

  def show; end

  def new
    @provider = @current_organization.providers.new
  end

  def create
    @provider = @current_organization.providers.new(provider_params)
    if @provider.save
      redirect_to tenant_provider_path(@provider), notice: "Provider created successfully."
    else
      render :new
    end
  end

  def edit; end

  def update
    if @provider.update(provider_params)
      redirect_to tenant_provider_path(@provider), notice: "Provider updated successfully."
    else
      render :edit
    end
  end

  def destroy
    if @provider.destroy
      redirect_to tenant_providers_path, notice: "Provider deleted successfully."
    else
      redirect_to tenant_providers_path, alert: "Failed to delete provider."
    end
    @provider.destroy
  end

  private

  def set_provider
    @provider = @current_organization.providers.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:first_name, :last_name, :specialty_id, :status, :email, :phone, :address)
  end
end
