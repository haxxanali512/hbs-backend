
class Tenant::ProvidersController < Tenant::BaseController
  before_action :set_provider, only: [ :show, :edit, :update, :destroy ]

  def index
    @providers = @current_organization.providers.kept.includes(:specialty, :user)
                                    .order(:first_name, :last_name)

    # Apply filters
    @providers = @providers.search(params[:search]) if params[:search].present?
    @providers = @providers.where(status: params[:status]) if params[:status].present?
    @providers = @providers.where(specialty_id: params[:specialty_id]) if params[:specialty_id].present?

    @pagy, @providers = pagy(@providers, items: 20)
    @specialties = Specialty.active.order(:name)
  end

  def show; end

  def new
    @provider = @current_organization.providers.new
    @specialties = Specialty.active.order(:name)
    @users = @current_organization.members.order(:first_name, :last_name)
  end

  def create
    @provider = @current_organization.providers.new(provider_params)
    if @provider.save
      redirect_to tenant_provider_path(@provider), notice: "Provider created successfully."
    else
      @specialties = Specialty.active.order(:name)
      @users = @current_organization.members.order(:first_name, :last_name)
      render :new
    end
  end

  def edit
    @specialties = Specialty.active.order(:name)
    @users = @current_organization.members.order(:first_name, :last_name)
  end

  def update
    if @provider.update(provider_params)
      redirect_to tenant_provider_path(@provider), notice: "Provider updated successfully."
    else
      @specialties = Specialty.active.order(:name)
      @users = @current_organization.members.order(:first_name, :last_name)
      render :edit
    end
  end

  def destroy
    if @provider.discard
      redirect_to tenant_providers_path, notice: "Provider deleted successfully."
    else
      redirect_to tenant_providers_path, alert: "Failed to delete provider."
    end
  end

  private

  def set_provider
    @provider = @current_organization.providers.kept.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:first_name, :last_name, :npi, :license_number, :license_state, :specialty_id, :status, :metadata)
  end
end
