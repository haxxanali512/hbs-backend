class Admin::OrganizationLocationsController < Admin::BaseController
  before_action :set_organization_location, only: [ :show, :edit, :update, :activate, :inactivate ]

  def index
    @organization_locations = OrganizationLocation.kept.includes(:organization)

    # Filtering
    @organization_locations = @organization_locations.by_status(params[:status]) if params[:status].present?
    @organization_locations = @organization_locations.joins(:organization).where(organizations: { id: params[:organization_id] }) if params[:organization_id].present?

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @organization_locations = @organization_locations.joins(:organization).where(
        "organization_locations.name ILIKE ? OR organization_locations.address_line_1 ILIKE ? OR organization_locations.address_line_2 ILIKE ? OR organizations.name ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Pagination
    @pagy, @organization_locations = pagy(@organization_locations, items: 20)

    # For filters
    @organizations = Organization.kept.order(:name)
    @statuses = OrganizationLocation.statuses.keys
  end

  def show
  end

  def edit
    @organizations = Organization.kept.order(:name)
  end

  def update
    if @organization_location.update(organization_location_params)
      redirect_to admin_organization_location_path(@organization_location), notice: "Organization location updated successfully."
    else
      @organizations = Organization.kept.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    if @organization_location.activate!
      redirect_to admin_organization_location_path(@organization_location), notice: "Organization location activated successfully."
    else
      redirect_to admin_organization_location_path(@organization_location), alert: "Failed to activate organization location."
    end
  end

  def inactivate
    if @organization_location.inactivate!
      redirect_to admin_organization_location_path(@organization_location), notice: "Organization location inactivated successfully."
    else
      redirect_to admin_organization_location_path(@organization_location), alert: "Failed to inactivate organization location."
    end
  end

  private

  def set_organization_location
    @organization_location = OrganizationLocation.kept.find(params[:id])
  end

  def organization_location_params
    params.require(:organization_location).permit(
      :organization_id, :name, :address_line_1, :address_line_2, :city, :state, :postal_code, :country, :phone_number,
      :place_of_service_code, :billing_npi, :is_virtual, :status, :notes_internal
    )
  end
end
