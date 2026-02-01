class Admin::ProvidersController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration

  # Alias the concern method before we override it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :approve, :reactivate ]

  def index
    @providers = Provider.kept.includes(:organizations, :specialties).recent

    # Filtering
    @providers = @providers.by_status(params[:status]) if params[:status].present?
    @providers = @providers.joins(:organizations).where(organizations: { id: params[:organization_id] }) if params[:organization_id].present?
    @providers = @providers.by_specialty(params[:specialty_id]) if params[:specialty_id].present?

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @providers = @providers.joins(:organizations).where(
        "providers.first_name ILIKE ? OR providers.last_name ILIKE ? OR providers.npi ILIKE ? OR organizations.name ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Pagination
    @pagy, @providers = pagy(@providers, items: 20)

    # For filters
    @organizations = Organization.order(:name)
    @statuses = Provider.statuses.keys
    @specialties = Specialty.order(:name) if defined?(Specialty)
  end

  def show
  end

  def new
    @provider = Provider.new
    @provider.provider_assignments.build
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.kept.order(:name)
  end

  def create
    @provider = Provider.new(provider_params.except(:specialty_ids))

    # Handle specialty assignments
    if params[:provider][:specialty_ids].present?
      specialty_ids = params[:provider][:specialty_ids].reject(&:blank?)
      @provider.specialty_ids = specialty_ids
    end

    # Ensure status defaults to 'drafted' if not provided or invalid
    if @provider.status.blank? || !Provider.statuses.key?(@provider.status)
      @provider.status = "drafted"
    end

    if @provider.save
      redirect_to admin_provider_path(@provider), notice: "Provider created successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.kept.order(:name)
      render :new
    end
  end

  def edit
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.kept.order(:name)
  end

  def update
    # Handle specialty assignments
    if params[:provider][:specialty_ids].present?
      specialty_ids = params[:provider][:specialty_ids].reject(&:blank?)
      @provider.specialty_ids = specialty_ids
    end

    if @provider.update(provider_params.except(:specialty_ids))
      redirect_to admin_provider_path(@provider), notice: "Provider updated successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.kept.order(:name)
      render :edit
    end
  end

  def destroy
    # Deactivate instead of delete - historical records remain
    if @provider.can_be_deactivated? && @provider.deactivate!
      redirect_to admin_providers_path, notice: "Provider deactivated successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to deactivate provider."
    end
  end

  def approve
    if @provider.approve!
      notify_organizations(:notify_provider_approved)
      redirect_to admin_provider_path(@provider), notice: "Provider approved successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to approve provider."
    end
  end

  def reactivate
    if @provider.reactivate!
      notify_organizations(:notify_provider_approved)
      redirect_to admin_provider_path(@provider), notice: "Provider reactivated successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to reactivate provider."
    end
  end

  def bulk_approve
    provider_ids = params[:provider_ids]
    if provider_ids.present?
      providers = Provider.where(id: provider_ids, status: "pending")
      approved_count = 0

      providers.each do |provider|
        authorize provider, :approve?
        if provider.approve!
          approved_count += 1
        end
      end

      redirect_to admin_providers_path, notice: "#{approved_count} providers approved successfully."
    else
      redirect_to admin_providers_path, alert: "No providers selected."
    end
  end

  def fetch_from_ezclaim
    fetch_from_ezclaim_concern(resource_type: :providers, service_method: :get_providers)
  end

  def save_from_ezclaim
    perform_ezclaim_save(
      model_class: Provider,
      data_key: :providers,
      mapping_proc: ->(provider_data) {
        # Find or initialize by NPI (most unique identifier)
        npi = provider_data["npi"] || provider_data["provider_id"] || provider_data["id"]
        specialty_id = map_specialty_from_ezclaim(provider_data["specialty"] || provider_data["specialty_id"])

        # Skip if no specialty found (Provider requires specialty_id)
        unless specialty_id
          return {
            find_by: {},
            attributes: {},
            skip: true,
            skip_reason: "No specialty found. Please set a specialty manually."
          }
        end

        {
          find_by: npi.present? ? { npi: npi } : {
            first_name: provider_data["first_name"] || provider_data["firstname"] || "",
            last_name: provider_data["last_name"] || provider_data["lastname"] || ""
          },
          attributes: {
            first_name: provider_data["first_name"] || provider_data["firstname"] || "Unknown",
            last_name: provider_data["last_name"] || provider_data["lastname"] || "Provider",
            npi: npi,
            license_number: provider_data["license_number"] || provider_data["license"] || nil,
            license_state: provider_data["license_state"] || provider_data["state"] || nil,
            status: :drafted,
            specialty_ids: [ specialty_id ].compact
          }
        }
      }
    )
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def notify_organizations(notification_method)
    @provider.organizations.each do |organization|
      NotificationService.public_send(notification_method, @provider, organization)
    end
  end

  def provider_params
    params.require(:provider).permit(
      :first_name, :last_name, :npi, :license_number, :license_state, :is_specialist,
      :metadata, specialty_ids: [], documents: [],
      provider_assignments_attributes: [ :id, :organization_id, :role, :active, :_destroy ]
    )
  end

  def map_specialty_from_ezclaim(ezclaim_specialty)
    # Try to find specialty by name or code from EZclaim data
    # If not found, use the first available specialty as default
    # This is a placeholder - you may want to implement proper mapping
    if ezclaim_specialty.present?
      specialty = Specialty.find_by("name ILIKE ?", "%#{ezclaim_specialty}%")
      return specialty.id if specialty
    end

    # Default to first specialty if available
    Specialty.first&.id
  end
end
