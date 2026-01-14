class Tenant::OrganizationLocationsController < Tenant::BaseController
  before_action :set_current_organization
  before_action :set_organization_location, only: [ :show, :edit, :update, :destroy, :activate, :inactivate, :reactivate ]

  def index
    # Load all locations for the organization
    all_locations = @current_organization.organization_locations.kept

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      all_locations = all_locations.where(
        "name ILIKE ? OR address_line_1 ILIKE ? OR address_line_2 ILIKE ? OR city ILIKE ? OR state ILIKE ?",
        search_term, search_term, search_term, search_term, search_term
      )
    end

    # Group by address type
    @servicing_addresses = all_locations.servicing.active.order(created_at: :desc)
    @billing_addresses = all_locations.billing.active.order(created_at: :desc)
    @remittance_address = all_locations.remittance.active.first # Only one remittance address allowed
  end

  def show
  end

  def new
    @organization_location = @current_organization.organization_locations.build(
      address_type: params[:address_type] || :servicing
    )
  end

  def create
    @organization_location = @current_organization.organization_locations.build(organization_location_params)

    if @organization_location.save
      redirect_to tenant_organization_locations_path, notice: "Address created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @organization_location.update(organization_location_params)
      redirect_to tenant_organization_locations_path, notice: "Address updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @organization_location.remittance?
      redirect_to tenant_organization_locations_path, alert: "Remittance addresses cannot be deleted. Please edit instead."
      return
    end

    if @organization_location.discard
      redirect_to tenant_organization_locations_path, notice: "Address deleted successfully."
    else
      redirect_to tenant_organization_locations_path, alert: "Failed to delete address."
    end
  end

  def activate
    if @organization_location.activate!
      redirect_to tenant_organization_location_path(@organization_location), notice: "Location activated successfully."
    else
      redirect_to tenant_organization_location_path(@organization_location), alert: "Failed to activate location."
    end
  end

  def inactivate
    if @organization_location.inactivate!
      redirect_to tenant_organization_location_path(@organization_location), notice: "Location inactivated successfully."
    else
      redirect_to tenant_organization_location_path(@organization_location), alert: "Failed to inactivate location."
    end
  end

  def reactivate
    if @organization_location.reactivate!
      redirect_to tenant_organization_location_path(@organization_location), notice: "Location reactivated successfully."
    else
      redirect_to tenant_organization_location_path(@organization_location), alert: "Failed to reactivate location."
    end
  end

  private

  def set_organization_location
    @organization_location = @current_organization.organization_locations.kept.find(params[:id])
  end

  def organization_location_params
    params.require(:organization_location).permit(
      :name, :address_line_1, :address_line_2, :city, :state, :postal_code, :country, :phone_number,
      :place_of_service_code, :billing_npi, :is_virtual, :status, :address_type, :notes_internal
    )
  end
end
