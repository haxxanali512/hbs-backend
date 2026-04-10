
class Tenant::ProvidersController < Tenant::BaseController
  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :remind_approval ]

  def index
    @providers = @current_organization.providers.kept.includes(:specialties)
                                    .order(:first_name, :last_name)

    # Apply filters
    @providers = @providers.search(params[:search]) if params[:search].present?
    if params[:status].present?
      @providers =
        if params[:status] == "active"
          @providers.where(status: [ "pending", "approved" ])
        else
          @providers.where(status: params[:status])
        end
    end
    @providers = @providers.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    @pagy, @providers = pagy(@providers, items: 20)
    @specialties = Specialty.active.order(:name)
  end

  def show; end

  def new
    @provider = Provider.new(status: "pending")
    @specialties = Specialty.active.order(:name)
  end

  def create
    if link_existing_provider_by_npi
      redirect_to tenant_providers_path,
        notice: "Provider with this NPI already existed; it has been linked to your organization."
      return
    end

    build_new_provider

    if @provider.save
      redirect_to tenant_providers_path,
        notice: "Provider created successfully."
    else
      load_specialties
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @specialties = Specialty.active.order(:name)
  end

  def update
    # Handle specialty assignments
    if params[:provider][:specialty_ids].present?
      specialty_ids = params[:provider][:specialty_ids].reject(&:blank?)
      @provider.specialty_ids = specialty_ids
    end

    if @provider.update(provider_params.except(:specialty_ids))
      redirect_to tenant_providers_path, notice: "Provider updated successfully."
    else
      @specialties = Specialty.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def remind_approval
    redirect_to tenant_provider_path(@provider), notice: "This provider is already in review; no separate approval workflow is required."
  end

  def destroy
    # Deactivate instead of delete
    if @provider.can_be_deactivated? && @provider.deactivate
      redirect_to tenant_providers_path, notice: "Provider deactivated successfully."
    else
      redirect_to tenant_providers_path, alert: "Failed to deactivate provider."
    end
  end

  private

  def set_provider
    @provider = @current_organization.providers.kept.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(:first_name, :last_name, :npi, :license_number, :license_state, :is_specialist, :metadata, specialty_ids: [], documents: [])
  end

  def link_existing_provider_by_npi
    npi = provider_params[:npi].to_s.strip
    return false if npi.blank?

    existing_provider = Provider.kept.find_by(npi: npi)
    return false unless existing_provider

    @provider = existing_provider

    return true if @provider.organizations.exists?(@current_organization.id)

    ProviderAssignment.create!(
      provider: @provider,
      organization: @current_organization,
      role: :primary,
      active: true
    )

    true
  end

  def build_new_provider
    @provider = Provider.new(
      provider_params.except(:specialty_ids).merge(status: "pending")
    )

    @provider.assign_to_organization_id = @current_organization.id
    assign_specialties
  end

  def assign_specialties
    specialty_ids = provider_params[:specialty_ids].reject(&:blank?)
    @provider.specialty_ids = specialty_ids if specialty_ids.present?
  end

  def submit_for_approval_safely
    return unless @provider.may_submit_for_approval?

    @provider.submit_for_approval
  rescue => e
    Rails.logger.error(
      "Failed to submit provider #{@provider.id} for approval: #{e.message}"
    )
  end

  def load_specialties
    @specialties = Specialty.active.order(:name)
  end
end
