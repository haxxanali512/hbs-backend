class Admin::ProvidersController < Admin::BaseController
  include Admin::Concerns::EzclaimIntegration

  # Alias the concern method before we override it
  alias_method :fetch_from_ezclaim_concern, :fetch_from_ezclaim

  before_action :set_provider, only: [ :show, :edit, :update, :destroy, :approve, :reject, :suspend, :reactivate, :resubmit ]

  def index
    @providers = Provider.kept.includes(:organizations, :specialty).recent

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
    @documents = @provider.documents.includes(:document_attachments).recent
  end

  def new
    @provider = Provider.new
    @provider.provider_assignments.build
    @organizations = Organization.kept.order(:name)
    @specialties = Specialty.kept.order(:name)
  end

  def create
    @provider = Provider.new(provider_params)

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
    if @provider.update(provider_params)
      redirect_to admin_provider_path(@provider), notice: "Provider updated successfully."
    else
      @organizations = Organization.kept.order(:name)
      @specialties = Specialty.kept.order(:name)
      render :edit
    end
  end

  def destroy
    if @provider.discard
      redirect_to admin_providers_path, notice: "Provider deleted successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to delete provider."
    end
  end

  def approve
    if @provider.approve!
      redirect_to admin_provider_path(@provider), notice: "Provider approved successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to approve provider."
    end
  end

  def reject
    if @provider.reject!
      redirect_to admin_provider_path(@provider), notice: "Provider rejected successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to reject provider."
    end
  end

  def suspend
    if @provider.suspend!
      redirect_to admin_provider_path(@provider), notice: "Provider suspended successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to suspend provider."
    end
  end

  def reactivate
    if @provider.reactivate!
      redirect_to admin_provider_path(@provider), notice: "Provider reactivated successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to reactivate provider."
    end
  end

  def resubmit
    if @provider.resubmit!
      redirect_to admin_provider_path(@provider), notice: "Provider resubmitted successfully."
    else
      redirect_to admin_provider_path(@provider), alert: "Failed to resubmit provider."
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

  def bulk_reject
    provider_ids = params[:provider_ids]
    if provider_ids.present?
      providers = Provider.where(id: provider_ids, status: "pending")
      rejected_count = 0

      providers.each do |provider|
        authorize provider, :reject?
        if provider.reject!
          rejected_count += 1
        end
      end

      redirect_to admin_providers_path, notice: "#{rejected_count} providers rejected successfully."
    else
      redirect_to admin_providers_path, alert: "No providers selected."
    end
  end

  def fetch_from_ezclaim
    fetch_from_ezclaim_concern(resource_type: :providers, service_method: :get_providers)
  end

  def save_from_ezclaim
    save_from_ezclaim(
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
            status: :draft,
            specialty_id: specialty_id
          }
        }
      }
    )
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(
      :first_name, :last_name, :npi, :license_number, :license_state,
      :specialty_id, :user_id, :status, :metadata,
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
